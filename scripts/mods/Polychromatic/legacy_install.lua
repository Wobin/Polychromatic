local DECLARATIONS = {
	"int AssetRedirect_PackagesStateStart(const char* custom_root, char* out, int cap);",
	"int AssetRedirect_PackagesRemoveStart(const char* stage, char* out, int cap);",
	"int AssetRedirect_PackagesPoll(char* out, int cap);",
}
local STATE_START = "AssetRedirect_PackagesStateStart"
local REMOVE_START = "AssetRedirect_PackagesRemoveStart"
local POLL = "AssetRedirect_PackagesPoll"
local NOTHING_APPLIED = "nothing applied"
local DB_ERROR_KEY = "__polychromatic_legacy_db_error_told"
local RETRY_INTERVAL = 1

local os_clock = os.clock

local ipairs = ipairs
local pcall = pcall
local rawget = rawget
local rawset = rawset
local tostring = tostring
local type = type
local unpack = unpack
local string_gmatch = string.gmatch
local string_match = string.match
local table_concat = table.concat

return function(mod, deps)
	local ffi = deps.ffi
	local json = deps.json
	local JOBS = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/package_jobs")(ffi, json)
	local legacy = {}
	local _lib = nil
	local _declared = false
	local _job = nil
	local _orphan = nil

	local function now()
		return (deps.clock or os_clock)()
	end

	local function modules()
		return deps.modules or {}
	end

	local function stage_root()
		return deps.folder() .. "/install_stage"
	end

	local function native()
		if _lib then
			return _lib
		end

		if not ffi or not json then
			return nil
		end

		if not _declared then
			_declared = true

			for _, declaration in ipairs(DECLARATIONS) do
				pcall(ffi.cdef, declaration)
			end
		end

		local lib = deps.native()

		if not lib then
			return nil
		end

		_lib = lib

		return _lib
	end

	local function async_exports()
		return deps.has(STATE_START) and deps.has(REMOVE_START) and deps.has(POLL)
	end

	local function display_name(id)
		return (string.gsub(string.gsub(id, "_", " "), "^%l", string.upper))
	end

	local function module_set()
		local parts = {}

		for _, manifest in ipairs(modules()) do
			parts[#parts + 1] = tostring(manifest.id) .. "@" .. tostring(manifest.version)
		end

		return table_concat(parts, ";")
	end

	function legacy.module_changes(saved)
		local added, removed, changed = {}, {}, {}
		local current = module_set()

		if type(saved) ~= "string" then
			return added, removed, changed, current
		end

		local before, order, seen = {}, {}, {}

		for entry in string_gmatch(saved, "[^;,]+") do
			local id, version = string_match(entry, "^(.-)@(.*)$")

			if id and before[id] == nil then
				before[id] = version
				order[#order + 1] = id
			end
		end

		for _, manifest in ipairs(modules()) do
			local id, version = tostring(manifest.id), tostring(manifest.version)
			local label = tostring(manifest.label or id) .. " " .. version

			seen[id] = true

			if before[id] == nil then
				added[#added + 1] = label
			elseif before[id] ~= version then
				changed[#changed + 1] = label
			end
		end

		for _, id in ipairs(order) do
			if not seen[id] then
				removed[#removed + 1] = display_name(id)
			end
		end

		return added, removed, changed, current
	end

	local function report(what, result)
		if result.ok then
			mod:info("legacy install: %s ok", what)
		else
			mod:info("legacy install: %s failed: %s", what, tostring(result.error))
		end

		if result.recovered ~= nil then
			mod:info("legacy install: %s recovered %s", what, tostring(result.recovered))
		end
	end

	local function tell_db_error(result)
		if type(result.db_error) == "string" and not rawget(_G, DB_ERROR_KEY) then
			rawset(_G, DB_ERROR_KEY, true)
			mod:info("legacy install: the bundle database could not be read and no install record exists, so nothing is applied: %s", result.db_error)
		end
	end

	local function nothing_applied(result)
		if type(result) ~= "table" then
			return false
		end

		if result.nothing_applied ~= nil then
			return result.nothing_applied == true
		end

		return result.ok == false and result.error == NOTHING_APPLIED
	end

	function legacy.busy()
		return _job ~= nil
	end

	function legacy.orphaned()
		return _orphan ~= nil
	end

	function legacy.abort(on_late)
		if _job and _job.running then
			_orphan = { job = _job.job, on_done = on_late }
		end

		_job = nil
	end

	local function finish(job, result)
		_job = nil
		job.on_done(result)
	end

	local function begin(job)
		local out, cap = JOBS.start_buffer()
		local args = job.args

		args[job.n + 1] = out
		args[job.n + 2] = cap
		job.last_try = now()

		local started = _lib[job.start](unpack(args, 1, job.n + 2))

		if started == 1 then
			job.running = true
		elseif started ~= 2 then
			finish(job, JOBS.start_result(job.start))
		end
	end

	local function run(start, args, n, name, on_done)
		_job = { start = start, args = args, n = n, job = name, on_done = on_done, running = false, last_try = 0 }
		begin(_job)
	end

	local function update_orphan()
		local orphan = _orphan
		local result = JOBS.poll(_lib, orphan.job)

		if result then
			_orphan = nil

			if orphan.on_done then
				orphan.on_done(result)
			end
		end
	end

	function legacy.update()
		if _orphan then
			update_orphan()
		end

		local job = _job

		if not job then
			return
		end

		if not job.running then
			if now() - job.last_try >= RETRY_INTERVAL then
				begin(job)
			end

			return
		end

		local result = JOBS.poll(_lib, job.job)

		if result then
			finish(job, result)
		end
	end

	local function state_then(on_done)
		run(STATE_START, { nil }, 1, "state", function(result)
			report("state", result)
			on_done(result)
		end)
	end

	function legacy.outcome(result)
		if nothing_applied(result) then
			return { ok = true, restored = false, job = result.job, nothing_applied = true }
		end

		if type(result) == "table" then
			result.restored = result.ok == true
		end

		return result
	end

	local function remove_then(on_done)
		run(REMOVE_START, { stage_root() }, 1, "restore", function(result)
			report("restore", result)
			on_done(legacy.outcome(result))
		end)
	end

	function legacy.cleanup(on_done)
		if not native() then
			on_done(nil)

			return
		end

		if not async_exports() then
			on_done({ ok = false, reason_key = "legacy_reason_dll_old", error = "the loaded asset redirect DLL has no " .. STATE_START })

			return
		end

		state_then(function(state)
			tell_db_error(state)

			if type(state.db_error) == "string" and not state.applied and not state.registered then
				on_done(nil)
			elseif state.ok == false then
				on_done(state)
			elseif state.applied or state.registered then
				remove_then(on_done)
			else
				on_done(nil)
			end
		end)
	end

	return legacy
end
