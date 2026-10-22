local LIB_VERSION = 10
local INSTANCE_KEY = "__asset_redirect_instance"
local CDEF_TYPE = "AssetRedirect_CDEF"
local INSTALLED_CDEF_TYPE = "AssetRedirect_INSTALLED_CDEF"
local VERIFY_CDEF_TYPE = "AssetRedirect_VERIFY_CDEF"
local DLL_NAME = "asset-redirect.dll"
local TEXT_CAP = 2048
local STATS_CAP = 262144
local STATS_RETRY_LIMIT = 67108864
local TRACE_CAP = 262144
local VERIFY_CAP = 65536
local MAIN_WAIT_MS = 25
local MAIN_WAIT_BUDGET_MS = 100

local _G = _G
local rawget = rawget
local rawset = rawset
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local tostring = tostring
local type = type
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local table_concat = table.concat
local table_sort = table.sort
local tonumber = tonumber

local existing = rawget(_G, INSTANCE_KEY)
local takeover = existing == nil or (not existing.committed and existing.core_version < LIB_VERSION)

if existing and existing.committed and LIB_VERSION > existing.core_version and LIB_VERSION > (existing.newer_available or 0) then
	existing.newer_available = LIB_VERSION
end

local instance = existing or {
	core = nil,
	core_version = 0,
	committed = false,
	committing = false,
	native = nil,
	native_state = "pending",
	native_error = nil,
	dll_version = nil,
	late = false,
	files = {},
	order = {},
	arrival = 0,
	candidates = {},
	stock_hashes = {},
	reported = {},
	command_mod = nil,
	newer_available = nil,
}

local function bound_native()
	if instance.native_state == "ready" then
		return instance.native
	end

	return nil
end

local function index_symbol(lib, symbol)
	return lib[symbol]
end

local function undeclared(err)
	return type(err) == "string" and err:find("missing declaration", 1, true) ~= nil
end

local function has_symbol(symbol)
	local lib = bound_native()

	if lib == nil or type(symbol) ~= "string" then
		return false
	end

	local cache = instance.symbols

	if cache == nil or instance.symbols_of ~= lib then
		cache = {}
		instance.symbols = cache
		instance.symbols_of = lib
	end

	local known = cache[symbol]

	if known ~= nil then
		return known
	end

	local ok, value = pcall(index_symbol, lib, symbol)
	local present = ok and value ~= nil

	if ok or not undeclared(value) then
		cache[symbol] = present
	end

	return present
end

local facade = {
	register = function(mod, spec)
		return instance.core.register(mod, spec, LIB_VERSION)
	end,
	commit = function()
		return instance.core.commit()
	end,
	state = function(handle)
		return instance.core.state(handle)
	end,
	winner = function(handle)
		return instance.core.winner(handle)
	end,
	pinned = function(handle)
		local pinned = instance.core.pinned

		if pinned then
			return pinned(handle)
		end

		return false
	end,
	opens = function(stock)
		local opens = instance.core.opens

		if opens then
			return opens(stock)
		end

		return nil
	end,
	clear = function(mod)
		return instance.core.clear(mod)
	end,
	version = function()
		return instance.core.version()
	end,
	ready = function()
		local ready = instance.core.ready

		if ready then
			return ready()
		end

		return true
	end,
	verified = function()
		local verified = instance.core.verified

		if verified then
			return verified()
		end

		return nil
	end,
	native = function()
		return bound_native()
	end,
	has = function(symbol)
		return has_symbol(symbol)
	end,
	load_native = function(mod)
		local load_early = instance.core.load_early

		if load_early then
			return load_early(mod, LIB_VERSION)
		end

		return bound_native()
	end,
	prune = function(mod, keep)
		local prune = instance.core.prune

		if prune then
			return prune(mod, keep)
		end

		return nil
	end,
	registered = function(mod)
		local registered = instance.core.registered

		if registered then
			return registered(mod)
		end

		return nil
	end,
	stats = function()
		local stats = instance.core.stats

		if stats then
			return stats()
		end

		return nil, "this library has no stats reader"
	end,
}

if not takeover then
	return facade
end

rawset(_G, INSTANCE_KEY, instance)

local Mods = rawget(_G, "Mods")
local ffi = Mods and Mods.lua and Mods.lua.ffi
local cjson = rawget(_G, "cjson")
local os_lib = rawget(_G, "os")
local clock = type(os_lib) == "table" and type(os_lib.clock) == "function" and os_lib.clock or nil

local CDEF = [[
	typedef struct { int unused; } AssetRedirect_CDEF;
	int AssetRedirect_Version(char* out, int cap);
	int AssetRedirect_Install(char* err, int errlen);
	int AssetRedirect_Add(const char* stock_rel, const char* replacement, const char* expect_stock_sha256, char* err, int errlen);
	int AssetRedirect_AddNew(const char* virtual_rel, const char* replacement, char* err, int errlen);
	int AssetRedirect_Remove(const char* stock_rel);
	int AssetRedirect_Opens(const char* stock_rel);
	int AssetRedirect_HashFile(const char* path, char* out, int cap);
	int AssetRedirect_Stats(char* out, int cap);
	int AssetRedirect_TraceEnable(int on);
	int AssetRedirect_TraceDump(char* out, int cap);
]]

local MODULE_CDEF = "void* GetModuleHandleA(const char* name);"
local INSTALLED_CDEF = "typedef struct { int unused; } AssetRedirect_INSTALLED_CDEF; int AssetRedirect_Installed(void);"
local VERIFY_CDEF = [[
	typedef struct { int unused; } AssetRedirect_VERIFY_CDEF;
	int AssetRedirect_VerifyStart(const char* list, char* out, int cap);
	int AssetRedirect_VerifyPoll(char* out, int cap);
	int AssetRedirect_VerifyEntry(const char* stock, char* out, int cap);
	int AssetRedirect_VerifyWait(const char* stock, int timeout_ms);
]]

local STATE_ORDER = { "active", "shared", "compatible", "displaced", "refused", "restart_required", "unavailable", "pending" }

local core = {}

local function text_buffer(size)
	return ffi.new("char[?]", size)
end

local function mod_folder(mod)
	return mod:get_internal_data("load_order_name") or mod:get_name()
end

local function file_record(stock)
	local file = instance.files[stock]

	if not file then
		file = { regs = {}, pushed = nil, winner = nil, restart = false }
		instance.files[stock] = file
		instance.order[#instance.order + 1] = stock
	end

	return file
end

local function note_candidate(mod, copy_version)
	local folder = mod_folder(mod)

	for _, candidate in ipairs(instance.candidates) do
		if candidate.folder == folder then
			candidate.mod = mod

			if copy_version > candidate.version then
				candidate.version = copy_version
			end

			return candidate
		end
	end

	local candidate = { folder = folder, version = copy_version, mod = mod }

	instance.candidates[#instance.candidates + 1] = candidate

	return candidate
end

local function hash_file(path)
	local out = text_buffer(TEXT_CAP)

	if instance.native.AssetRedirect_HashFile(path, out, TEXT_CAP) == 1 then
		return string_lower(ffi.string(out))
	end

	return nil, ffi.string(out)
end

local function call_stats(native, cap)
	local out = text_buffer(cap)
	local size = native.AssetRedirect_Stats(out, cap)

	return size, ffi.string(out)
end

local function read_stats()
	local native = bound_native()

	if not native then
		return nil, "the native library is not loaded"
	end

	if not cjson then
		return nil, "cjson is unavailable"
	end

	local cap = STATS_CAP
	local size, text = call_stats(native, cap)

	if size > 1 and size <= STATS_RETRY_LIMIT then
		cap = size
		size, text = call_stats(native, cap)
	end

	if size < 1 then
		return nil, string_format("the stats call failed or the stats did not fit in %d bytes", cap)
	end

	if text == "" then
		return nil, string_format("the stats did not fit in %d bytes", cap)
	end

	local ok, stats = pcall(cjson.decode, text)

	if ok and type(stats) == "table" then
		return stats
	end

	return nil, "the stats text is not readable"
end

local function seed_from_stats()
	local stats = read_stats()
	local entries = type(stats) == "table" and stats.entries

	if type(entries) ~= "table" then
		return
	end

	instance.stats_partial = stats.truncated == true

	for _, entry in ipairs(entries) do
		if type(entry.key) == "string" and entry.status == "pinned" then
			local file = file_record(entry.key)

			file.pinned = true
			file.restart = true
		elseif type(entry.key) == "string" and type(entry.replacement) == "string" and entry.virtual ~= true and (entry.status == nil or entry.status == "active") then
			local hash = hash_file(entry.replacement)

			if hash then
				file_record(entry.key).pushed = { path = entry.replacement, hash = hash }
			end
		end
	end
end

local function fail_native(mod, reason, path)
	instance.native_state = "unavailable"
	instance.native_error = reason

	mod:info("Asset Redirect library load failed from %s: %s", tostring(path), tostring(reason))

	if not instance.native_told then
		instance.native_told = true
		mod:error("%s", "Asset Redirect could not load its library, so replacement files are off this session. The reason is in the log.")
	end
end

local function load_native(candidate)
	local mod = candidate.mod

	if not ffi then
		fail_native(mod, "Mods.lua.ffi is unavailable", DLL_NAME)

		return
	end

	if not pcall(ffi.typeof, CDEF_TYPE) then
		ffi.cdef(CDEF)
	end

	if not pcall(function() return ffi.C.GetModuleHandleA end) then
		ffi.cdef(MODULE_CDEF)
	end

	if not pcall(ffi.typeof, INSTALLED_CDEF_TYPE) then
		ffi.cdef(INSTALLED_CDEF)
	end

	local path = "../mods/" .. candidate.folder .. "/bin/" .. DLL_NAME

	if ffi.C.GetModuleHandleA(DLL_NAME) ~= nil then
		instance.late = true
		path = DLL_NAME
	end

	instance.native_candidate = candidate
	instance.native_path = path

	local ok, lib = pcall(ffi.load, path)

	if not ok then
		instance.native_load_failed = true
		fail_native(mod, tostring(lib), path)

		return
	end

	instance.native_load_failed = false

	if instance.late then
		local probed, installed = pcall(function() return lib.AssetRedirect_Installed() end)

		if probed and installed == 0 then
			instance.late = false
		end
	end

	local err = text_buffer(TEXT_CAP)

	if lib.AssetRedirect_Install(err, TEXT_CAP) ~= 1 then
		fail_native(mod, ffi.string(err), path)

		return
	end

	instance.native = lib
	instance.native_state = "ready"

	if not pcall(ffi.typeof, VERIFY_CDEF_TYPE) then
		pcall(ffi.cdef, VERIFY_CDEF)
	end

	local has_verify, verify_start = pcall(function() return lib.AssetRedirect_VerifyStart end)

	instance.can_verify = has_verify and verify_start ~= nil

	local version = text_buffer(64)

	if lib.AssetRedirect_Version(version, 64) == 1 then
		instance.dll_version = ffi.string(version)
	end

	if instance.late then
		seed_from_stats()
	end
end

local function report(reg, reason)
	local key = reg.owner .. "|" .. reg.stock .. "|" .. reason

	if instance.reported[key] then
		return
	end

	instance.reported[key] = true

	reg.mod:info("Asset Redirect left %s stock: %s", reg.stock, reason)
end

local function refuse(reg, reason)
	reg.valid = false
	reg.reason = reason

	report(reg, reason)
end

local function bad_relative(path)
	return type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:find("\\", 1, true) ~= nil or path:find("..", 1, true) ~= nil
end

local function is_absolute(path)
	return type(path) == "string" and (path:find("^%a:[\\/]") ~= nil or path:find("^[\\/][\\/][^\\/]+[\\/][^\\/]+") ~= nil)
end

local function parent_segment(path)
	local padded = "/" .. path .. "/"

	return padded:find("[\\/]%.%.?[\\/]") ~= nil
end

local function bad_file(path)
	if is_absolute(path) then
		return parent_segment((path:gsub("^[\\/][\\/]", "")))
	end

	return bad_relative(path)
end

local function payload_path_of(reg)
	local file = reg.spec.file

	if is_absolute(file) then
		return file
	end

	return "mods/" .. mod_folder(reg.mod) .. "/" .. file
end

local function field_error(spec)
	if type(spec) ~= "table" then
		return "the registration is not a table"
	end

	if bad_relative(spec.stock) or spec.stock ~= string_lower(spec.stock) then
		return "stock must be a lowercase path under bundle with forward slashes"
	end

	if bad_file(spec.file) then
		return "file must be a path inside the mod folder with forward slashes"
	end

	if spec.virtual == true then
		if spec.sha256 ~= nil then
			return "a virtual registration has no stock file, so it takes no sha256"
		end
	elseif type(spec.sha256) ~= "string" or #spec.sha256 ~= 64 or spec.sha256:find("^%x+$") == nil then
		return "sha256 must be 64 hex digits"
	end

	if spec.virtual ~= nil and type(spec.virtual) ~= "boolean" then
		return "virtual must be true or false"
	end

	if spec.priority ~= nil and (type(spec.priority) ~= "number" or spec.priority ~= math_floor(spec.priority)) then
		return "priority must be a whole number"
	end

	if spec.contract ~= nil and (type(spec.contract) ~= "string" or spec.contract == "") then
		return "contract must be a non-empty string"
	end

	if spec.late ~= nil and type(spec.late) ~= "boolean" then
		return "late must be true or false"
	end

	return nil
end

local function stock_hash(stock)
	local cached = instance.stock_hashes[stock]

	if cached then
		return cached
	end

	local hash, err = hash_file("bundle/" .. stock)

	if hash then
		instance.stock_hashes[stock] = hash
	end

	return hash, err
end

local function evaluate(reg)
	local spec = reg.spec
	local reason = field_error(spec)

	if reason then
		return reason
	end

	if spec.virtual ~= true then
		local expected = string_lower(spec.sha256)
		local actual, err = stock_hash(spec.stock)

		if not actual then
			return "cannot read the stock file: " .. tostring(err)
		end

		if actual ~= expected then
			return string_format("the stock file has changed (sha256 %s, expected %s)", actual, expected)
		end
	end

	local payload = payload_path_of(reg)
	local hash, payload_err = hash_file(payload)

	if not hash then
		return "cannot read the payload: " .. tostring(payload_err)
	end

	reg.payload_path = payload
	reg.payload_hash = hash

	return nil
end

local PINNED_REASON = "it was opened as stock before it was verified, so it stays stock until the game restarts"

local function validate(reg)
	reg.valid = false
	reg.reason = nil
	reg.payload_path = nil
	reg.payload_hash = nil

	local file = instance.files[reg.stock]

	if file and file.pinned then
		refuse(reg, PINNED_REASON)

		return
	end

	local reason = evaluate(reg)

	if reason then
		refuse(reg, reason)
	else
		reg.valid = true
	end
end

local function pick_winner(file)
	local best

	for _, reg in ipairs(file.regs) do
		if reg.valid and (not best or reg.priority > best.priority or (reg.priority == best.priority and reg.arrival < best.arrival)) then
			best = reg
		end
	end

	return best
end

local function resolve(stock)
	local file = instance.files[stock]
	local native = instance.native

	if file.pinned then
		return
	end

	for _ = 1, #file.regs + 1 do
		local winner = pick_winner(file)
		local pushed = file.pushed
		local target_hash = winner and winner.payload_hash
		local pushed_hash = pushed and pushed.hash

		local same_bytes = target_hash ~= nil and target_hash == pushed_hash

		if target_hash == pushed_hash and (not same_bytes or winner.payload_path == pushed.path) then
			file.winner = winner

			return
		end

		local late_winner = winner and winner.spec.late == true
		local late_removal = winner == nil and file.winner ~= nil and file.winner.spec.late == true

		if not same_bytes then
			if late_winner or late_removal then
				if pushed == nil and native.AssetRedirect_Opens(stock) > 0 then
					file.restart = true
				end
			elseif native.AssetRedirect_Opens(stock) > 0 or (pushed == nil and (instance.committed or instance.late)) then
				file.restart = true
			end
		end

		if not winner then
			native.AssetRedirect_Remove(stock)
			file.pushed = nil
			file.winner = nil

			return
		end

		local err = text_buffer(TEXT_CAP)

		local added

		if winner.spec.virtual == true then
			added = native.AssetRedirect_AddNew(stock, winner.payload_path, err, TEXT_CAP)
		else
			added = native.AssetRedirect_Add(stock, winner.payload_path, winner.expect, err, TEXT_CAP)
		end

		if added == 1 then
			file.pushed = { path = winner.payload_path, hash = target_hash }
			file.winner = winner

			return
		end

		refuse(winner, ffi.string(err))
	end
end

local JSON_ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\" }

local function json_escape(c)
	return JSON_ESCAPES[c] or string_format("\\u%04x", c:byte())
end

local function json_string(text)
	return '"' .. (text:gsub('[%c"\\]', json_escape)) .. '"'
end

local function decode(text)
	local ok, value = pcall(cjson.decode, text)

	if ok and type(value) == "table" then
		return value
	end

	return nil
end

local function verify_buffer(need)
	if not instance.verify_buf or instance.verify_cap < need then
		instance.verify_cap = need
		instance.verify_buf = text_buffer(need)
	end

	return instance.verify_buf, instance.verify_cap
end

local function by_preference(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end

	return a.arrival < b.arrival
end

local function start_verify()
	local parts = {}
	local regs_by_stock = {}

	for _, stock in ipairs(instance.order) do
		local file = instance.files[stock]
		local sendable = {}

		for _, reg in ipairs(file.regs) do
			reg.valid = false
			reg.reason = nil
			reg.payload_path = nil
			reg.payload_hash = nil

			local reason = field_error(reg.spec)

			if reason then
				refuse(reg, reason)
			else
				sendable[#sendable + 1] = reg
			end
		end

		if #sendable > 0 then
			table_sort(sendable, by_preference)
			regs_by_stock[stock] = sendable

			local candidates = {}

			for i, reg in ipairs(sendable) do
				local is_virtual = reg.spec.virtual == true

				reg.verify_path = payload_path_of(reg)
				candidates[i] = string_format('{"file":%s,"sha256":%s,"virtual":%s}', json_string(reg.verify_path), is_virtual and "null" or json_string(reg.expect), is_virtual and "true" or "false")
			end

			parts[#parts + 1] = string_format('{"stock":%s,"candidates":[%s]}', json_string(stock), table_concat(candidates, ","))
		end
	end

	if #parts == 0 then
		return false
	end

	local out = text_buffer(TEXT_CAP)

	if instance.native.AssetRedirect_VerifyStart('{"entries":[' .. table_concat(parts, ",") .. ']}', out, TEXT_CAP) ~= 1 then
		return false
	end

	for _, stock in ipairs(instance.order) do
		local file = instance.files[stock]

		if regs_by_stock[stock] then
			file.verified = false
		else
			file.winner = nil
		end
	end

	instance.verify_regs = regs_by_stock
	instance.verify_wait_left = MAIN_WAIT_BUDGET_MS
	instance.verifying = true

	return true
end

local function apply_result(stock, item)
	local file = instance.files[stock]

	if not file or file.verified ~= false then
		return
	end

	file.verified = true

	local regs = instance.verify_regs[stock] or {}

	if item.timed_out == true then
		for _, reg in ipairs(regs) do
			refuse(reg, "verification did not finish in time, so the stock file stays this session")
		end

		file.winner = nil
		file.pushed = nil
		file.restart = item.pinned == true
		file.pinned = true

		return
	end

	local candidates = type(item.candidates) == "table" and item.candidates or {}
	local stock_sha = type(item.stock_sha) == "string" and string_lower(item.stock_sha) or nil

	if stock_sha then
		instance.stock_hashes[stock] = stock_sha
	end

	for i, reg in ipairs(regs) do
		local candidate = type(candidates[i]) == "table" and candidates[i] or {}
		local reason

		if reg.spec.virtual ~= true then
			if not stock_sha then
				reason = "cannot read the stock file: " .. tostring(item.stock_error)
			elseif stock_sha ~= reg.expect then
				reason = string_format("the stock file has changed (sha256 %s, expected %s)", stock_sha, tostring(reg.expect))
			end
		end

		if not reason then
			if type(candidate.payload_sha) == "string" then
				reg.payload_path = reg.verify_path
				reg.payload_hash = string_lower(candidate.payload_sha)
			else
				reason = "cannot read the payload: " .. tostring(candidate.payload_error)
			end
		end

		if reason then
			refuse(reg, reason)
		else
			reg.valid = true
		end
	end

	local winner

	for i, reg in ipairs(regs) do
		if reg.valid then
			local add_error = type(candidates[i]) == "table" and candidates[i].add_error

			if type(add_error) == "string" then
				refuse(reg, add_error)
			else
				winner = reg

				break
			end
		end
	end

	local active = tonumber(item.active) or -1
	local served = active >= 0 and regs[active + 1] or nil

	if served ~= winner then
		winner = served
	end

	file.winner = winner

	if winner and item.pinned ~= true then
		file.pushed = { path = winner.payload_path, hash = winner.payload_hash }
	else
		file.pushed = nil
	end

	if item.pinned == true then
		file.restart = true
		file.pinned = true

		if winner then
			report(winner, "the engine opened it before verification finished, so the stock file stays this session")
		end
	end
end

local function bounded_wait(stock)
	local left = instance.verify_wait_left or 0

	if left <= 0 then
		return
	end

	local wait = left < MAIN_WAIT_MS and left or MAIN_WAIT_MS
	local started = clock and clock()
	local settled = instance.native.AssetRedirect_VerifyWait(stock, wait)
	local spent = wait

	if started and settled == 1 then
		spent = math_floor((clock() - started) * 1000 + 1)
		spent = spent < wait and spent or wait
	end

	if settled == 0 then
		instance.verify_wait_left = 0
	else
		instance.verify_wait_left = left - spent
	end
end

local function settle_stock(stock)
	local file = instance.files[stock]

	if not instance.verifying or not file or file.verified ~= false then
		return
	end

	local native = instance.native

	bounded_wait(stock)

	local buffer, cap = verify_buffer(VERIFY_CAP)
	local written = native.AssetRedirect_VerifyEntry(stock, buffer, cap)

	if written > 1 then
		buffer, cap = verify_buffer(written)
		written = native.AssetRedirect_VerifyEntry(stock, buffer, cap)
	end

	local item = written == 1 and decode(ffi.string(buffer))

	if item then
		apply_result(stock, item)
	end
end

local function run_deferred()
	local deferred = instance.deferred

	if not deferred then
		return
	end

	instance.deferred = nil

	local stocks = deferred.stocks

	for _, reg in ipairs(deferred.regs) do
		reg.deferred = nil
		stocks[#stocks + 1] = reg.stock
	end

	if instance.native_state ~= "ready" then
		return
	end

	for _, reg in ipairs(deferred.regs) do
		validate(reg)
	end

	local seen = {}

	for _, stock in ipairs(stocks) do
		if not seen[stock] and instance.files[stock] then
			seen[stock] = true
			resolve(stock)
		end
	end
end

local function defer(reg, stock)
	local deferred = instance.deferred

	if not deferred then
		deferred = { regs = {}, stocks = {} }
		instance.deferred = deferred
	end

	if reg then
		reg.deferred = true
		deferred.regs[#deferred.regs + 1] = reg
	else
		deferred.stocks[#deferred.stocks + 1] = stock
	end
end

local function finish_verify(block)
	if not instance.verifying then
		return true
	end

	local native = instance.native

	if block then
		bounded_wait(nil)
	end

	local buffer, cap = verify_buffer(VERIFY_CAP)
	local polled = native.AssetRedirect_VerifyPoll(buffer, cap)

	if polled > 1 then
		buffer, cap = verify_buffer(polled)
		polled = native.AssetRedirect_VerifyPoll(buffer, cap)
	end

	if polled == 0 then
		return false
	end

	local result = polled == 1 and decode(ffi.string(buffer)) or {}
	local items = type(result.items) == "table" and result.items or {}

	for _, item in ipairs(items) do
		if type(item) == "table" and type(item.stock) == "string" then
			apply_result(item.stock, item)
		end
	end

	instance.verifying = false
	instance.verify_ms = tonumber(result.elapsed_ms)
	instance.verify_hashed = tonumber(result.hashed_bytes)
	instance.verify_pinned = tonumber(result.pinned)

	run_deferred()

	return true
end

function core.ready()
	return finish_verify(false)
end

function core.verified()
	return instance.verify_ms, instance.verify_hashed, instance.verify_pinned
end

local function best_candidate()
	local best

	for _, candidate in ipairs(instance.candidates) do
		if not best or candidate.version > best.version then
			best = candidate
		end
	end

	return best
end

local function newer_copy_after_failure(best)
	local tried = instance.native_candidate

	return instance.native_state == "unavailable" and instance.native_load_failed == true and best ~= nil and tried ~= nil and best.version > tried.version
end

local function bind_best()
	local best = best_candidate()

	if best and (instance.native_state == "pending" or newer_copy_after_failure(best)) then
		load_native(best)
	end

	local bound = instance.native_candidate

	if instance.committing and instance.native_state == "ready" and best and bound and best.version > bound.version then
		best.mod:info("Asset Redirect library %d in %s runs with the DLL bound early from %s (library %d)", best.version, tostring(best.folder), tostring(bound.folder), bound.version)
	end
end

function core.load_early(mod, copy_version)
	note_candidate(mod, copy_version)

	if not instance.committed and not instance.committing then
		bind_best()
	end

	return bound_native()
end

function core.stats()
	return read_stats()
end

function core.commit()
	if instance.committed or instance.committing then
		return
	end

	instance.committing = true

	bind_best()

	local background = instance.native_state == "ready" and instance.can_verify and not instance.late and cjson ~= nil and start_verify()

	if instance.native_state == "ready" and not background then
		for _, stock in ipairs(instance.order) do
			for _, reg in ipairs(instance.files[stock].regs) do
				validate(reg)
			end

			resolve(stock)
		end
	end

	instance.committing = false
	instance.committed = true
end

function core.state(reg)
	if not instance.committed then
		return "pending"
	end

	if instance.native_state ~= "ready" then
		return "unavailable"
	end

	if reg.deferred then
		finish_verify(true)

		if reg.deferred then
			return "pending"
		end
	end

	if instance.verifying then
		settle_stock(reg.stock)

		if instance.files[reg.stock].verified == false then
			return "pending"
		end
	end

	local file = instance.files[reg.stock]

	if file.pinned and file.restart then
		return "restart_required"
	end

	if not reg.valid then
		return "refused"
	end

	if file.restart then
		return "restart_required"
	end

	local winner = file.winner

	if winner == reg then
		return "active"
	end

	if not winner then
		return "refused"
	end

	if winner.payload_hash == reg.payload_hash then
		return "shared"
	end

	if reg.contract and reg.contract == winner.contract then
		return "compatible"
	end

	return "displaced"
end

function core.winner(reg)
	if instance.verifying then
		settle_stock(reg.stock)
	end

	local file = instance.files[reg.stock]
	local winner = file and file.winner

	if not winner then
		return nil
	end

	return winner.owner, winner.contract
end

function core.pinned(reg)
	local stock = type(reg) == "table" and reg.stock
	local file = stock and instance.files[stock]

	return type(file) == "table" and file.pinned == true
end

function core.opens(stock)
	local native = instance.native

	if native == nil or type(stock) ~= "string" then
		return nil
	end

	local ok, count = pcall(function() return native.AssetRedirect_Opens(stock) end)

	if ok and type(count) == "number" then
		return count
	end

	return nil
end

local function print_status(mod)
	core.commit()
	finish_verify(true)

	local native = instance.native
	local counts = {}

	for _, stock in ipairs(instance.order) do
		local file = instance.files[stock]
		local parts = {}

		for _, reg in ipairs(file.regs) do
			local state = core.state(reg)

			counts[state] = (counts[state] or 0) + 1
			parts[#parts + 1] = string_format("%s=%s", reg.owner, state)
		end

		local opens = native and native.AssetRedirect_Opens(stock) or -1
		local winner = file.winner and file.winner.owner or "none"

		mod:info("%s winner=%s opens=%d %s", stock, winner, opens, table_concat(parts, " "))
	end

	local summary = {}

	for _, state in ipairs(STATE_ORDER) do
		if counts[state] then
			summary[#summary + 1] = string_format("%s %d", state, counts[state])
		end
	end

	mod:echo("%s", string_format("Asset Redirect %d, DLL %s: %d files, %s. Details are in the log.", LIB_VERSION, tostring(instance.dll_version), #instance.order, #summary > 0 and table_concat(summary, ", ") or "no registrations"))

	if instance.newer_available then
		mod:echo("%s", string_format("A newer Asset Redirect (library %d) is installed. It takes over after a restart.", instance.newer_available))
	end

	if instance.native_error then
		mod:info("Asset Redirect library error: %s", tostring(instance.native_error))
		mod:echo("%s", "Asset Redirect library error. The reason is in the log.")
	end
end

local function trace_command(mod, choice)
	core.commit()

	local native = instance.native

	if not native then
		mod:echo("%s", "Asset Redirect library is not loaded.")

		return
	end

	if choice == "on" or choice == "off" then
		native.AssetRedirect_TraceEnable(choice == "on" and 1 or 0)
		mod:echo("%s", "Asset Redirect trace " .. choice .. ".")

		return
	end

	if choice == "dump" then
		local out = text_buffer(TRACE_CAP)
		local length = native.AssetRedirect_TraceDump(out, TRACE_CAP)

		if length >= TRACE_CAP then
			out = text_buffer(length + 1)
			length = native.AssetRedirect_TraceDump(out, length + 1)
		end

		if length < 0 then
			mod:echo("%s", "Asset Redirect trace dump failed.")

			return
		end

		mod:info("trace %s", ffi.string(out))
		mod:echo("%s", "Asset Redirect trace written to the log.")

		return
	end

	mod:echo("%s", "Usage: /asset_redirect trace on|off|dump")
end

function core.command(sub, choice)
	local mod = instance.command_mod

	if sub == "trace" then
		trace_command(mod, choice)

		return
	end

	print_status(mod)
end

local function ensure_command(mod)
	local current = instance.command_mod
	local get_mod = rawget(_G, "get_mod")

	if current and get_mod and get_mod(current:get_name()) == current then
		return
	end

	instance.command_mod = mod

	mod:command("asset_redirect", "Asset Redirect: list redirected files and their states. Add trace on, trace off or trace dump for the file trace.", function(...)
		return instance.core.command(...)
	end)
end

function core.register(mod, spec, copy_version)
	local owner = mod:get_name()
	local is_table = type(spec) == "table"
	local stock = is_table and type(spec.stock) == "string" and spec.stock or "?"
	local file = file_record(stock)
	local reg

	for _, candidate in ipairs(file.regs) do
		if candidate.owner == owner then
			reg = candidate

			break
		end
	end

	if not reg then
		instance.arrival = instance.arrival + 1
		reg = { owner = owner, stock = stock, arrival = instance.arrival, valid = false }
		file.regs[#file.regs + 1] = reg
	end

	reg.mod = mod
	reg.spec = spec
	reg.priority = is_table and type(spec.priority) == "number" and spec.priority or 0
	reg.contract = is_table and spec.contract or nil
	reg.expect = is_table and type(spec.sha256) == "string" and string_lower(spec.sha256) or nil

	local candidate = note_candidate(mod, copy_version)

	ensure_command(mod)

	if not instance.committed then
		return reg
	end

	if instance.native_state == "pending" then
		load_native(candidate)
	end

	if not finish_verify(true) then
		if not reg.deferred then
			defer(reg)
		end

		return reg
	end

	if instance.native_state == "ready" then
		validate(reg)
		resolve(stock)
	end

	return reg
end

local function drop_owned(owner, keep)
	local settled = finish_verify(true)
	local dropped = 0

	for stock, file in pairs(instance.files) do
		if not (keep and keep[stock]) then
			local kept = {}

			for _, reg in ipairs(file.regs) do
				if reg.owner ~= owner then
					kept[#kept + 1] = reg
				end
			end

			if #kept ~= #file.regs then
				dropped = dropped + #file.regs - #kept
				file.regs = kept

				if not settled then
					defer(nil, stock)
				elseif instance.committed and instance.native_state == "ready" then
					resolve(stock)
				end
			end
		end
	end

	return dropped
end

function core.clear(mod)
	drop_owned(mod:get_name(), nil)
end

function core.prune(mod, keep)
	return drop_owned(mod:get_name(), type(keep) == "table" and keep or {})
end

function core.registered(mod)
	local owner = mod:get_name()
	local list = {}

	for stock, file in pairs(instance.files) do
		for _, reg in ipairs(file.regs) do
			if reg.owner == owner then
				list[#list + 1] = stock

				break
			end
		end
	end

	table_sort(list)

	return list
end

function core.version()
	return LIB_VERSION, instance.dll_version
end

instance.core = core
instance.core_version = LIB_VERSION

return facade
