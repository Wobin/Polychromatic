local JOB = "hosts"
local START = "AssetRedirect_HostsStart"
local POLL = "AssetRedirect_PackagesPoll"
local DECLARATIONS = {
	"int AssetRedirect_HostsStart(const char* request, char* out, int cap);",
	"int AssetRedirect_PackagesPoll(char* out, int cap);",
}
local REGISTERED_KEY = "__polychromatic_hosts_registered"
local FALLBACK_KEY = "__polychromatic_hosts_cache_fallback"
local RETRY_INTERVAL = 1
local BUSY_LIMIT = 60
local JOB_LIMIT = 120

local os_clock = os.clock

local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local rawget = rawget
local rawset = rawset
local tostring = tostring
local type = type
local string_match = string.match

local REDIRECT_STATES = {
	active = "active",
	shared = "active",
	compatible = "displaced",
	displaced = "displaced",
	refused = "refused",
	restart_required = "restart_required",
	pending = "pending",
}

local WORST = {
	active = 0,
	pending = 1,
	displaced = 2,
	restart_required = 3,
	refused = 4,
	failed = 5,
}

local REASON_KEYS = {
	in_use = "host_reason_in_use",
	displaced = "host_reason_displaced",
	restart_required = "host_reason_restart_required",
	unassigned = "host_reason_unassigned",
	refused = "host_reason_refused",
	failed = "host_reason_failed",
}

return function(mod, deps)
	local ffi = deps.ffi
	local json = deps.json
	local rows = type(deps.table) == "table" and deps.table.hosts or {}
	local names = type(deps.table) == "table" and deps.table.packages or {}
	local JOBS = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/package_jobs")(ffi, json)

	local hosts = {}
	local _lib = nil
	local _job = false
	local _job_started = 0
	local _ready = false
	local _busy_failed = false
	local _entries = {}
	local _cache_dir = nil
	local _cache_fallback = nil
	local _requested = {}
	local _declared = false
	local _enabled = true
	local _want_since = nil
	local _last_try = 0

	local function now()
		return (deps.clock or os_clock)()
	end

	function hosts.global_table(key)
		local value = rawget(_G, key)

		if type(value) ~= "table" then
			value = {}
			rawset(_G, key, value)
		end

		return value
	end

	local function native()
		if not ffi then
			return nil, "host_reason_no_native"
		end

		if not _declared then
			_declared = true

			for _, declaration in ipairs(DECLARATIONS) do
				pcall(ffi.cdef, declaration)
			end
		end

		local lib = deps.native()

		if not lib then
			return nil, "host_reason_no_native"
		end

		if not deps.has(START) or not deps.has(POLL) then
			return nil, "host_reason_dll_old"
		end

		return lib, nil
	end

	local function asset_names(manifest)
		local assets = {}

		if type(manifest) == "table" and type(manifest.packages) == "table" then
			for _, asset in ipairs(manifest.packages) do
				if type(asset) == "string" then
					assets[#assets + 1] = asset
				end
			end
		end

		return assets
	end

	local function fail(module, key, detail)
		_entries[module] = { failed = true, reason_key = key, detail = detail }
		mod:info("host packages: %s failed: %s", tostring(module), tostring(detail or key))
	end

	local function fail_requested(key, detail)
		for i = 1, #_requested do
			fail(_requested[i], key, detail)
		end
	end

	local function note_requested(list)
		_entries = {}
		_requested = {}

		for i = 1, #list do
			_requested[i] = list[i].module
		end
	end

	function hosts.requests()
		local list, unassigned = {}, {}
		local folder = deps.folder()

		for _, manifest in ipairs(deps.modules or {}) do
			local assets = asset_names(manifest)

			if #assets > 0 then
				local id = manifest.id
				local host = rows[id]

				if host then
					local roots = {}

					for i, asset in ipairs(assets) do
						roots[i] = folder .. "/modules/" .. id .. "/Packages/" .. asset
					end

					list[#list + 1] = { module = id, host = host, roots = roots }
				else
					unassigned[#unassigned + 1] = id
				end
			end
		end

		return list, unassigned
	end

	function hosts.start()
		if _job or not _enabled then
			return false
		end

		local lib = native()

		if not lib or not ffi or not json or not deps.asset_redirect then
			_want_since = nil
			_ready = true

			return false
		end

		local list = hosts.requests()

		if #list == 0 then
			_want_since = nil
			_ready = true

			return false
		end

		local out, cap = JOBS.start_buffer()
		local started = lib[START](json.encode({ hosts = list }), out, cap)

		_last_try = now()

		if started == 2 then
			_want_since = _want_since or _last_try

			return false
		end

		_want_since = nil
		_busy_failed = false
		_lib = lib
		_ready = false
		note_requested(list)

		if started == 1 then
			_job = true
			_job_started = _last_try

			return true
		end

		local refused = JOBS.start_result(START)

		fail_requested("host_reason_failed", type(refused.error) == "string" and refused.error or START .. " refused the request")
		_ready = true

		return false
	end

	local function registered_hosts()
		return hosts.global_table(REGISTERED_KEY)
	end

	local function in_use(package, host)
		if registered_hosts()[host] then
			return false
		end

		if package ~= nil and deps.package_loaded(package) == true then
			return true
		end

		local opens = deps.opens and deps.opens(host)

		return type(opens) == "number" and opens > 0
	end

	local function register_entry(entry, streams)
		local module = entry.module
		local host = entry.host
		local package = names[host]
		local record = {
			records = entry.records,
			cached = entry.cached,
			streams = #streams,
			key = string_match(entry.replacement, "([^\\/]+)$"),
			stream_handles = {},
		}

		_entries[module] = record

		if in_use(package, host) then
			record.in_use = true
			mod:info("host packages: %s host %s is in use", tostring(module), tostring(host))

			return
		end

		local redirect = deps.asset_redirect

		if not redirect then
			record.disabled = true

			return
		end

		record.host = host
		record.handle = redirect.register(mod, { stock = host, file = entry.replacement, sha256 = entry.stock_sha256, late = true })

		if record.handle then
			registered_hosts()[host] = true
		end

		for _, stream in ipairs(streams) do
			record.stream_handles[#record.stream_handles + 1] = {
				stock = stream.stock,
				handle = redirect.register(mod, { stock = stream.stock, file = stream.file, virtual = true, late = true }),
			}
		end
	end

	local function duplicate_stream(streams, claimed, module)
		for _, stream in ipairs(streams) do
			local owner = type(stream) == "table" and claimed[stream.stock]

			if owner and owner ~= module then
				return stream.stock, owner
			end
		end

		return nil
	end

	local function note_cache_folder(result)
		_cache_dir = type(result.cache_dir) == "string" and result.cache_dir or nil
		_cache_fallback = nil

		local fallback = result.cache_fallback

		if type(fallback) ~= "table" then
			return
		end

		_cache_fallback = { requested = fallback.requested, reason = fallback.reason }

		local told = hosts.global_table(FALLBACK_KEY)
		local key = tostring(fallback.requested) .. "|" .. tostring(_cache_dir)

		if not told[key] then
			told[key] = true
			mod:info("host packages: the cache folder %s could not be used (%s), so the folder %s is used for this session", tostring(fallback.requested), tostring(fallback.reason), tostring(_cache_dir))
		end
	end

	local function apply(result)
		_ready = true

		if type(result) ~= "table" or result.ok ~= true or result.job ~= JOB or type(result.hosts) ~= "table" then
			local why = type(result) == "table" and type(result.error) == "string" and result.error or "the host job returned no host list"

			fail_requested("host_reason_failed", why)

			return
		end

		note_cache_folder(result)

		local requested, seen, claimed = {}, {}, {}

		for i = 1, #_requested do
			requested[_requested[i]] = true
		end

		for _, entry in ipairs(result.hosts) do
			local module = type(entry) == "table" and entry.module

			if type(module) == "string" and requested[module] and not seen[module] and rows[module] == entry.host then
				seen[module] = true

				local streams = type(entry.streams) == "table" and entry.streams or {}
				local stock, owner = duplicate_stream(streams, claimed, module)

				if type(entry.error) == "string" then
					fail(module, "host_reason_failed", entry.error)
				elseif type(entry.replacement) ~= "string" or type(entry.stock_sha256) ~= "string" then
					fail(module, "host_reason_failed", "the host result has no replacement")
				elseif stock then
					fail(module, "host_reason_duplicate_stream", "stream " .. tostring(stock) .. " is also composed for " .. tostring(owner))
				else
					for _, stream in ipairs(streams) do
						if type(stream) == "table" and stream.stock ~= nil then
							claimed[stream.stock] = module
						end
					end

					register_entry(entry, streams)
				end
			end
		end

		for i = 1, #_requested do
			if not seen[_requested[i]] then
				fail(_requested[i], "host_reason_failed", "the host job returned no result for this module")
			end
		end
	end

	local function retry_busy()
		if not _enabled then
			_want_since = nil

			return
		end

		local t = now()

		if t - _want_since >= BUSY_LIMIT then
			_want_since = nil
			note_requested((hosts.requests()))
			fail_requested("host_reason_busy", "the native library stayed busy for " .. BUSY_LIMIT .. " s")
			_ready = true
			_busy_failed = true
		elseif t - _last_try >= RETRY_INTERVAL then
			hosts.start()
		end
	end

	function hosts.update()
		if _want_since and not _job then
			retry_busy()
		end

		if not _job then
			return
		end

		local result = JOBS.poll(_lib, JOB)

		if result == nil then
			if now() - _job_started >= JOB_LIMIT then
				_job = false
				fail_requested("host_reason_timeout", "the host job did not finish within " .. JOB_LIMIT .. " s")
				_ready = true
			end

			return
		end

		_job = false

		if not _enabled then
			_ready = false
			_entries = {}
			mod:info("host packages: the composition finished after effect packages were turned off, so nothing was registered")

			return
		end

		apply(result)
	end

	function hosts.busy()
		return _job
	end

	function hosts.ready()
		return _ready
	end

	function hosts.started()
		return _job or (_ready and not _busy_failed) or _want_since ~= nil
	end

	function hosts.set_enabled(flag)
		_enabled = flag ~= false

		if not _enabled then
			_want_since = nil
		end
	end

	function hosts.package_name(module)
		local host = rows[module]

		return host and names[host] or nil
	end

	local function redirect_state(handle)
		if not handle then
			return "failed", "host_reason_failed", "not registered"
		end

		local raw = deps.asset_redirect.state(handle)
		local state = REDIRECT_STATES[raw]

		if not state then
			return "failed", "host_reason_unavailable", "asset redirect state " .. tostring(raw)
		end

		if state == "refused" then
			local reason = type(handle) == "table" and handle.reason

			return state, "host_reason_refused", type(reason) == "string" and reason or nil
		end

		return state, nil, nil
	end

	function hosts.status(module)
		local host = rows[module]
		local status = {
			host = host,
			package = host and names[host] or nil,
			state = "pending",
			reason = nil,
			detail = nil,
			cached = nil,
			cache_dir = nil,
			cache_fallback = false,
			records = nil,
			streams = nil,
			in_use = false,
			key = nil,
		}

		if not _enabled then
			status.state = "disabled"

			return status
		end

		if not host then
			status.state = "unassigned"

			return status
		end

		local record = _entries[module]

		if not record then
			local lib, key = native()

			if not lib or not deps.asset_redirect then
				status.state = "disabled"
				status.reason = deps.asset_redirect and key and mod:localize(key) or nil
			end

			return status
		end

		status.cached = record.cached
		status.cache_dir = _cache_dir
		status.cache_fallback = _cache_fallback ~= nil
		status.records = record.records
		status.streams = record.streams
		status.key = record.key

		if record.failed then
			status.state = "failed"
			status.reason = mod:localize(record.reason_key or "host_reason_failed")
			status.detail = record.detail
		elseif record.in_use then
			status.state = "in_use"
			status.in_use = true
		elseif record.disabled or not record.handle then
			status.state = "disabled"
		else
			local key, detail

			status.state, key, detail = redirect_state(record.handle)
			status.reason = key and mod:localize(key) or nil
			status.detail = detail

			for _, stream in ipairs(record.stream_handles or {}) do
				local state, stream_key, stream_detail = redirect_state(stream.handle)

				if WORST[state] > WORST[status.state] then
					status.state = state
					status.stream = stream.stock
					status.reason = nil
					status.detail = nil

					if state == "refused" or state == "failed" then
						status.reason = mod:localize("host_reason_stream", mod:localize(stream_key or REASON_KEYS[state]))
						status.detail = tostring(stream.stock) .. ": " .. tostring(stream_detail)
					end
				end
			end
		end

		return status
	end

	function hosts.failure_text(status)
		local state = status.state

		if status.reason then
			return status.reason
		end

		if state == "disabled" or state == "active" or state == "pending" then
			return nil
		end

		local key = REASON_KEYS[state]

		return key and mod:localize(key) or nil
	end

	function hosts.active()
		local list = {}

		for _, manifest in ipairs(deps.modules or {}) do
			local id = type(manifest) == "table" and manifest.id

			if id and rows[id] then
				local status = hosts.status(id)

				if status.state == "active" then
					list[#list + 1] = { module = id, package = names[rows[id]], key = status.key }
				end
			end
		end

		return list
	end

	function hosts.stocks()
		local set = {}

		for _, record in pairs(_entries) do
			if record.handle and record.host then
				set[record.host] = true
			end

			for _, stream in ipairs(record.stream_handles or {}) do
				if stream.handle and stream.stock ~= nil then
					set[stream.stock] = true
				end
			end
		end

		return set
	end

	function hosts.prune(keep_extra)
		local redirect = deps.asset_redirect

		if not redirect or type(redirect.prune) ~= "function" then
			return nil
		end

		local keep = hosts.stocks()

		for stock in pairs(keep_extra or {}) do
			keep[stock] = true
		end

		local dropped = redirect.prune(mod, keep)
		local registered = registered_hosts()

		for host in pairs(registered) do
			if not keep[host] then
				registered[host] = nil
			end
		end

		if type(dropped) == "number" and dropped > 0 then
			mod:info("host packages: %d registrations for files no module provides any more were dropped", dropped)
		end

		return dropped
	end

	return hosts
end
