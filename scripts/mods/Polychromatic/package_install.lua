return function(mod, modules)
	local CDEF_TYPE = "AssetRedirect_PACKAGES_CDEF"
	local ASYNC_CDEF_TYPE = "AssetRedirect_PACKAGES_ASYNC_CDEF"
	local REMOVE_CDEF_TYPE = "AssetRedirect_PACKAGES_REMOVE_CDEF"
	local DLL_NAME = "asset-redirect.dll"
	local OUT_CAP = 65536
	local START_CAP = 4096
	local PACKAGE_ROOT = "content/mods/polychromatic/packages/"

	local rawget = rawget
	local pcall = pcall
	local tostring = tostring
	local type = type
	local unpack = unpack

	local Mods = rawget(_G, "Mods")
	local ffi = Mods and Mods.lua and Mods.lua.ffi
	local cjson = rawget(_G, "cjson")

	local BOOT_KEY = "__polychromatic_boot_install"
	local PENDING_KEY = "__polychromatic_pending_install"
	local MODULES_SETTING = "installed_modules"

	local installer = {}
	local _lib = nil
	local _lib_error = nil
	local _state = nil
	local _live = false
	local _async = false
	local _job = nil
	local _poll_out = nil
	local _poll_cap = 0
	local _start_out = nil

	local function folder()
		return mod:get_internal_data("load_order_name") or mod:get_name()
	end

	local function custom_root()
		local roots = { "mods/" .. folder() .. "/Packages" }

		for _, manifest in ipairs(modules or {}) do
			if manifest.packages and #manifest.packages > 0 then
				roots[#roots + 1] = "mods/" .. folder() .. "/modules/" .. manifest.id .. "/Packages"
			end
		end

		return table.concat(roots, ";")
	end

	local function stage_root()
		return "mods/" .. folder() .. "/install_stage"
	end

	local function native()
		if _lib or _lib_error then
			return _lib, _lib_error
		end

		if not ffi or not cjson then
			_lib_error = "ffi or cjson is unavailable"

			return nil, _lib_error
		end

		if not pcall(ffi.typeof, CDEF_TYPE) then
			ffi.cdef([[
				typedef struct { int unused; } AssetRedirect_PACKAGES_CDEF;
				int AssetRedirect_PackagesPlan(const char* custom_root, const char* stage, char* out, int cap);
				int AssetRedirect_PackagesApply(const char* stage, char* out, int cap);
				int AssetRedirect_PackagesRestore(char* out, int cap);
				int AssetRedirect_PackagesState(const char* custom_root, char* out, int cap);
			]])
		end

		local ok, lib = pcall(ffi.load, "../mods/" .. folder() .. "/bin/" .. DLL_NAME)

		if not ok then
			_lib_error = tostring(lib)

			return nil, _lib_error
		end

		if not pcall(function() return lib.AssetRedirect_PackagesState end) then
			_lib_error = "Polychromatic's asset redirect DLL predates the package installer"

			return nil, _lib_error
		end

		if not pcall(ffi.typeof, ASYNC_CDEF_TYPE) then
			ffi.cdef([[
				typedef struct { int unused; } AssetRedirect_PACKAGES_ASYNC_CDEF;
				int AssetRedirect_PackagesStateStart(const char* custom_root, char* out, int cap);
				int AssetRedirect_PackagesInstallStart(const char* custom_root, const char* stage, int restore_first, char* out, int cap);
				int AssetRedirect_PackagesPoll(char* out, int cap);
			]])
		end

		if not pcall(ffi.typeof, REMOVE_CDEF_TYPE) then
			ffi.cdef([[
				typedef struct { int unused; } AssetRedirect_PACKAGES_REMOVE_CDEF;
				int AssetRedirect_PackagesRemoveStart(const char* stage, char* out, int cap);
			]])
		end

		_async = pcall(function()
			return lib.AssetRedirect_PackagesStateStart, lib.AssetRedirect_PackagesInstallStart, lib.AssetRedirect_PackagesRemoveStart, lib.AssetRedirect_PackagesPoll
		end)
		_lib = lib

		return _lib
	end

	local function module_set()
		local parts = {}

		for _, manifest in ipairs(modules or {}) do
			parts[#parts + 1] = tostring(manifest.id) .. "@" .. tostring(manifest.version)
		end

		return table.concat(parts, ",")
	end

	local function display_name(id)
		return (string.gsub(string.gsub(id, "_", " "), "^%l", string.upper))
	end

	function installer.module_changes(record)
		local before, order, now = {}, {}, {}
		local added, updated, removed = {}, {}, {}

		for entry in string.gmatch(record or "", "[^,]+") do
			local id, version = string.match(entry, "^(.-)@(.*)$")

			if id and before[id] == nil then
				before[id] = version
				order[#order + 1] = id
			end
		end

		for _, manifest in ipairs(modules or {}) do
			local id, version = tostring(manifest.id), tostring(manifest.version)
			local label = tostring(manifest.label or id) .. " " .. version

			now[id] = true

			if before[id] == nil then
				added[#added + 1] = label
			elseif before[id] ~= version then
				updated[#updated + 1] = label
			end
		end

		for _, id in ipairs(order) do
			if not now[id] then
				removed[#removed + 1] = display_name(id)
			end
		end

		local clauses = {}

		for _, clause in ipairs({ { "added", added }, { "updated", updated }, { "removed", removed } }) do
			if #clause[2] > 0 then
				clauses[#clauses + 1] = clause[1] .. " " .. table.concat(clause[2], ", ")
			end
		end

		return table.concat(clauses, ", ")
	end

	local function decode(name, text)
		local ok, decoded = pcall(cjson.decode, text)

		if not ok or type(decoded) ~= "table" then
			return { ok = false, error = name .. " returned unreadable output" }
		end

		return decoded
	end

	local function call(name, ...)
		local lib, why = native()

		if not lib then
			return { ok = false, error = why }
		end

		local out = ffi.new("char[?]", OUT_CAP)
		local args = { ... }
		args[#args + 1] = out
		args[#args + 1] = OUT_CAP
		lib[name](unpack(args))

		return decode(name, ffi.string(out))
	end

	local function report(what, result)
		if result.ok then
			mod:info("package install: %s ok", what)
		else
			mod:info("package install: %s failed: %s", what, tostring(result.error))
		end
	end

	installer.call = call

	function installer.async()
		local lib = native()

		return lib ~= nil and _async
	end

	function installer.busy()
		return _job ~= nil
	end

	local function finish(job, result)
		_job = nil
		job.on_done(result)
	end

	local function begin(job)
		local started = _lib[job.start](unpack(job.args, 1, job.n))

		if started == 1 then
			job.running = true
		elseif started ~= 2 then
			finish(job, decode(job.start, ffi.string(_start_out)))
		end
	end

	local function run(start, args, on_done)
		if not _start_out then
			_start_out = ffi.new("char[?]", START_CAP)
		end

		local n = #args

		args[n + 1] = _start_out
		args[n + 2] = START_CAP
		_job = { start = start, args = args, n = n + 2, on_done = on_done, running = false }
		begin(_job)
	end

	function installer.update()
		local job = _job

		if not job then
			return
		end

		if not job.running then
			begin(job)

			return
		end

		if not _poll_out then
			_poll_out = ffi.new("char[?]", OUT_CAP)
			_poll_cap = OUT_CAP
		end

		local polled = _lib.AssetRedirect_PackagesPoll(_poll_out, _poll_cap)

		if polled == 0 then
			return
		end

		if polled == 1 then
			finish(job, decode("AssetRedirect_PackagesPoll", ffi.string(_poll_out)))
		elseif polled > 1 then
			_poll_out = ffi.new("char[?]", polled)
			_poll_cap = polled
		else
			finish(job, { ok = false, error = "the package job finished without a result" })
		end
	end

	function installer.last_state()
		return _state
	end

	function installer.state()
		_state = installer.call("AssetRedirect_PackagesState", custom_root())
		report("state", _state)

		return _state
	end

	function installer.state_then(on_done)
		if not installer.async() then
			on_done(installer.state())

			return
		end

		run("AssetRedirect_PackagesStateStart", { custom_root() }, function(result)
			_state = result
			report("state", result)
			on_done(result)
		end)
	end

	function installer.install(force, known)
		local state = known or installer.state()

		if not state.ok then
			return state
		end

		if state.current and not force then
			return { ok = true, unchanged = true }
		end

		if state.registered or state.stale then
			local restored = installer.call("AssetRedirect_PackagesRestore")
			report("restore before reinstall", restored)

			if not restored.ok then
				return restored
			end
		end

		local planned = installer.call("AssetRedirect_PackagesPlan", custom_root(), stage_root())
		report("plan", planned)

		if not planned.ok then
			return planned
		end

		local applied = installer.call("AssetRedirect_PackagesApply", stage_root())
		report("apply", applied)
		applied.installed = applied.ok

		return applied
	end

	function installer.install_then(force, state, on_done, changes)
		if not installer.async() then
			on_done(installer.install(force, state))

			return
		end

		if not state.ok then
			on_done(state)

			return
		end

		if state.current and not force then
			on_done({ ok = true, unchanged = true })

			return
		end

		local restore_first = (state.registered or state.stale) and 1 or 0

		rawset(_G, PENDING_KEY, { modules = module_set(), changes = changes })
		run("AssetRedirect_PackagesInstallStart", { custom_root(), stage_root(), restore_first }, function(result)
			rawset(_G, PENDING_KEY, nil)
			_state = nil

			local steps = type(result.steps) == "table" and result.steps or {}

			for i = 1, #steps do
				local step = steps[i]

				report(tostring(step.what), { ok = step.ok == true, error = step.error })
			end

			if #steps == 0 then
				report("install", result)
			end

			result.installed = result.ok == true and result.installed == true

			on_done(result)
		end)
	end

	function installer.remove(known)
		if _live then
			return { ok = true, deferred = true }
		end

		local state = known or installer.state()

		if not state.ok or not state.applied then
			return state
		end

		local restored = installer.call("AssetRedirect_PackagesRestore")
		report("restore", restored)
		restored.restored = restored.ok

		return restored
	end

	function installer.remove_then(state, on_done)
		if _live then
			on_done({ ok = true, deferred = true })

			return
		end

		if not installer.async() then
			on_done(installer.remove(state))

			return
		end

		if not state.ok or not state.applied then
			on_done(state)

			return
		end

		run("AssetRedirect_PackagesRemoveStart", { stage_root() }, function(result)
			_state = nil
			report("restore", result)
			result.restored = result.ok

			on_done(result)
		end)
	end

	local function boot_snapshot(state)
		local boot = rawget(_G, BOOT_KEY)

		if boot == nil then
			local names = {}
			local list = type(state) == "table" and state.ok ~= false and state.current == true and state.render_settings

			if type(list) == "table" then
				for i = 1, #list do
					if type(list[i]) == "string" then
						names[list[i]] = true
					end
				end
			end

			boot = { live = type(state) == "table" and state.ok ~= false and state.current == true, render_settings = names }
			rawset(_G, BOOT_KEY, boot)
		end

		return boot
	end

	local function record(result)
		if result.ok ~= false then
			mod:set(MODULES_SETTING, module_set())
		end

		return result
	end

	local function decide(enabled, state, done)
		local boot = boot_snapshot(state)
		local adopted = rawget(_G, PENDING_KEY)

		if adopted ~= nil then
			rawset(_G, PENDING_KEY, nil)

			if enabled and type(adopted) == "table" and adopted.modules == module_set() and state.ok ~= false and state.current then
				local result = record(state)

				result.installed = true
				result.modules_changed = adopted.changes
				done(result)

				return
			end
		end

		if not enabled then
			installer.remove_then(state, done)

			return
		end

		if not modules or #modules == 0 then
			installer.remove_then(state, function(result)
				record(result)
				result.no_modules = result.restored
				done(result)
			end)

			return
		end

		local recorded = mod:get(MODULES_SETTING)
		local in_use = state.ok ~= false and state.current and boot.live

		if type(recorded) == "string" and recorded ~= module_set() and not in_use then
			local changes = installer.module_changes(recorded)

			installer.install_then(true, state, function(result)
				record(result)

				if result.ok then
					result.modules_changed = changes
				end

				done(result)
			end, changes)

			return
		end

		if in_use then
			_live = true
			done(record(state))

			return
		end

		if state.ok ~= false and state.current then
			done(record(state))

			return
		end

		installer.install_then(false, state, function(result)
			done(record(result))
		end)
	end

	function installer.startup(enabled, on_done)
		_live = false

		local finished = nil

		installer.state_then(function(state)
			decide(enabled, state, function(result)
				finished = result

				if on_done then
					on_done(result)
				end
			end)
		end)

		return finished
	end

	function installer.live()
		return _live
	end

	function installer.package_name(asset_id)
		local asset = asset_id:match("^Polychromatic:(.+)$") or asset_id

		return PACKAGE_ROOT .. asset
	end

	function installer.render_settings()
		local boot = rawget(_G, BOOT_KEY)

		if not _live or type(boot) ~= "table" then
			return {}
		end

		return boot.render_settings
	end

	return installer
end
