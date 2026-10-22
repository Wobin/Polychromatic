return function(mod, module_data, deps)
	local CA_PALETTES = module_data("ca_palettes")
	local CA_ASSETS = module_data("ca_assets")
	local ASSET_PREFIX = "Polychromatic:"
	local HOSTS = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/host_packages")(mod, deps)
	local LEGACY = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/legacy_install")(mod, deps)
	local LOADS_KEY = "__polychromatic_host_loads"
	local RELEASES_KEY = "__polychromatic_host_releases"
	local SESSION_KEY = "__polychromatic_session_started"
	local LEGACY_TIMEOUT = 30
	local RETRY_INTERVAL = 1
	local RELEASE_WAIT = 10
	local MODULES_SETTING = "installed_modules"
	local LEGACY_TOLD_SETTING = "legacy_install_failure_told"
	local RESOURCE_ROOT = "^content/mods/polychromatic/([^/]+)/"

	local ipairs = ipairs
	local next = next
	local pairs = pairs
	local rawget = rawget
	local rawset = rawset
	local tostring = tostring
	local type = type
	local string_match = string.match

	local _ready = {}
	local _current = {}
	local _generation = 0
	local _dirty = true
	local _retry_at = nil
	local _was_running = false
	local _unconfirmed = false
	local _failures_told = {}
	local _failures_settled = false
	local _failures_check_at = nil
	local _legacy_finish = nil
	local _legacy_started = 0
	local _enabled = true
	local _held_since = nil
	local _held_told = false
	local _prune_wanted = true
	local clock = deps.clock or os.clock
	local global_table = HOSTS.global_table
	local packages = {}

	local function package_manager()
		local managers = rawget(_G, "Managers")

		return managers and managers.package
	end

	local function manifest_of(module)
		for _, manifest in ipairs(deps.modules or {}) do
			if type(manifest) == "table" and manifest.id == module then
				return manifest
			end
		end

		return nil
	end

	local function module_of(package)
		for _, manifest in ipairs(deps.modules or {}) do
			local id = type(manifest) == "table" and manifest.id

			if id and HOSTS.package_name(id) == package then
				return id
			end
		end

		return nil
	end

	local _fallback_logged = {}

	local function asset_ids(asset)
		local ids = {}

		for _, id in ipairs(type(CA_ASSETS) == "table" and CA_ASSETS or {}) do
			if type(id) == "string" and string_match(id, "([^:]*)$") == asset then
				ids[#ids + 1] = id
			end
		end

		if #ids == 0 then
			ids[1] = ASSET_PREFIX .. asset

			if not _fallback_logged[asset] then
				_fallback_logged[asset] = true
				mod:info("host packages: %s is not in the module asset list, marking %s", asset, ids[1])
			end
		end

		return ids
	end

	local function bump()
		_generation = _generation + 1
		_retry_at = nil
	end

	local function mark(module, value)
		local manifest = manifest_of(module)

		if manifest and type(manifest.packages) == "table" then
			for _, asset in ipairs(manifest.packages) do
				if type(asset) == "string" then
					for _, id in ipairs(asset_ids(asset)) do
						_ready[id] = value
					end
				end
			end
		end

		bump()
	end

	local function held(module)
		for _, record in pairs(_current) do
			if record.module == module then
				return true
			end
		end

		return false
	end

	local function nothing_held()
		local pending = rawget(_G, RELEASES_KEY)
		local loads = rawget(_G, LOADS_KEY)

		return next(_current) == nil and not (pending and pending[1]) and not (type(loads) == "table" and next(loads) ~= nil)
	end

	local function release_list(list)
		local manager = package_manager()

		for i = #list, 1, -1 do
			local entry = list[i]

			list[i] = nil

			if manager then
				manager:release(entry.id)
			end

			mod:info("host package %s released", tostring(entry.package))

			local module = entry.module

			if module and not held(module) then
				mark(module, nil)
			end
		end

		_dirty = true
		bump()
	end

	local function has_assets(manifest)
		if type(manifest.packages) ~= "table" then
			return false
		end

		for _, asset in ipairs(manifest.packages) do
			if type(asset) == "string" then
				return true
			end
		end

		return false
	end

	local function any_pending()
		for _, manifest in ipairs(deps.modules or {}) do
			local id = type(manifest) == "table" and manifest.id

			if id and HOSTS.package_name(id) and has_assets(manifest) and HOSTS.status(id).state == "pending" then
				return true
			end
		end

		return false
	end

	local function pending_release(package)
		local pending = rawget(_G, RELEASES_KEY)

		if pending then
			for i = 1, #pending do
				if pending[i].package == package then
					return true
				end
			end
		end

		return false
	end

	local function adopted_waits(package, record, manager)
		local module = record.module

		if not module then
			record.stale = true

			return false
		end

		if not HOSTS.ready() then
			return true
		end

		local status = HOSTS.status(module)

		if status.state == "pending" then
			return true
		end

		if status.state ~= "active" or status.key == nil or status.key ~= record.key then
			record.stale = true
			mod:info("host package %s held from before the reload does not match the current %s host: it is released at the next release point", tostring(package), tostring(module))

			return false
		end

		if manager and manager:has_loaded(package) then
			record.loaded = true
			mark(module, true)

			return false
		end

		return true
	end

	local function confirm_adopted()
		local manager = package_manager()
		local waiting = false

		for package, record in pairs(_current) do
			if record.adopted and not record.loaded and not record.stale and adopted_waits(package, record, manager) then
				waiting = true
			end
		end

		_unconfirmed = waiting
	end

	function packages.adopt()
		local loads = global_table(LOADS_KEY)

		for package, entry in pairs(loads) do
			if not _current[package] then
				local id, key = entry, nil

				if type(entry) == "table" then
					id, key = entry.id, entry.key
				end

				_current[package] = { id = id, key = key, module = module_of(package), adopted = true }
			end
		end

		confirm_adopted()
	end

	local function migrate()
		if mod:get("effect_packages_migrated") ~= true then
			mod:set("effect_packages_enabled", mod:get("effect_packages_removed") ~= true)
			mod:set("effect_packages_migrated", true)
		end

		if mod:get("effect_packages_removed") ~= nil then
			mod:set("effect_packages_removed", nil)
		end
	end

	local function tell_module_changes()
		local reload = rawget(_G, SESSION_KEY) == true
		local added, removed, changed, current = LEGACY.module_changes(mod:get(MODULES_SETTING))

		rawset(_G, SESSION_KEY, true)

		if reload then
			for _, clause in ipairs({
				{ "modules_added", added },
				{ "modules_removed", removed },
				{ "modules_changed_refresh", changed },
			}) do
				if #clause[2] > 0 then
					mod:echo("%s", mod:localize(clause[1], table.concat(clause[2], ", ")))
				end
			end
		end

		mod:set(MODULES_SETTING, current)
	end

	local function tell_failures()
		local settled = true
		local told = {}
		local total = 0

		for _, manifest in ipairs(deps.modules or {}) do
			local id = type(manifest) == "table" and manifest.id

			if id and has_assets(manifest) then
				total = total + 1
			end

			if id and not _failures_told[id] and has_assets(manifest) then
				local status = HOSTS.status(id)
				local text = HOSTS.failure_text(status)

				if text then
					_failures_told[id] = true

					if status.detail then
						mod:info("host packages: %s stays stock: %s", tostring(id), tostring(status.detail))
					end

					if deps.asset_redirect then
						told[#told + 1] = { label = manifest.label or id, text = text }
					else
						mod:info("host packages: %s stays stock: %s", tostring(id), tostring(text))
					end
				elseif status.state ~= "pending" then
					_failures_told[id] = true
				else
					settled = false
				end
			end
		end

		local shared = #told > 0 and #told == total and told[1].text

		for i = 2, #told do
			if told[i].text ~= shared then
				shared = nil
			end
		end

		if shared then
			mod:echo("%s", mod:localize("hosts_failed", shared))
		else
			for _, entry in ipairs(told) do
				mod:echo("%s", mod:localize("host_failed", entry.label, entry.text))
			end
		end

		_failures_settled = settled
		_failures_check_at = not settled and clock() + RETRY_INTERVAL or nil
	end

	local function start_hosts()
		_failures_told = {}
		_failures_settled = false
		_failures_check_at = nil
		_prune_wanted = true
		HOSTS.start()
	end

	local function legacy_told(detail)
		if type(detail) == "string" then
			if mod:get(LEGACY_TOLD_SETTING) == detail then
				return true
			end

			mod:set(LEGACY_TOLD_SETTING, detail)

			return false
		end

		if mod:get(LEGACY_TOLD_SETTING) ~= nil then
			mod:set(LEGACY_TOLD_SETTING, nil)
		end

		return false
	end

	local function tell_legacy(result)
		if type(result) ~= "table" then
			legacy_told(nil)

			return
		end

		if result.ok == false or (result.restored == false and result.error ~= nil) then
			local detail = tostring(result.error or "unknown error")

			mod:info("legacy install removal failed: %s", detail)

			if not legacy_told(detail) then
				mod:echo("%s", mod:localize(result.reason_key or "legacy_install_failed"))
			end
		else
			legacy_told(nil)

			if result.restored then
				mod:echo("%s", mod:localize("legacy_install_removed"))
			elseif result.nothing_applied then
				mod:info("legacy install: nothing was applied, so there is nothing to remove")
			end
		end
	end

	local function late_legacy(result)
		mod:info("legacy install: the %s job finished after the wait: %s", tostring(result.job), result.ok and "ok" or tostring(result.error))

		if result.job == "restore" then
			local outcome = LEGACY.outcome(result)

			if outcome.ok then
				tell_legacy(outcome)
			end
		end
	end

	function packages.startup()
		_dirty = true
		migrate()

		_enabled = mod:get("effect_packages_enabled") ~= false
		HOSTS.set_enabled(_enabled)

		local finished = false

		_legacy_finish = function(result)
			if finished then
				return
			end

			finished = true
			_legacy_finish = nil

			tell_legacy(result)

			if _enabled then
				start_hosts()
			end
		end
		_legacy_started = clock()

		if not _enabled then
			packages.release_when_idle()
		end

		LEGACY.cleanup(_legacy_finish)

		tell_module_changes()
	end

	function packages.acquire()
		local manager = package_manager()

		if not _enabled or not HOSTS.ready() or not deps.gameplay_running() then
			return
		end

		if not manager then
			_dirty = true

			return
		end

		local loads = global_table(LOADS_KEY)
		local active = HOSTS.active()
		local retry = false
		local reference = mod:get_name()

		for i = 1, #active do
			local module = active[i].module
			local package = active[i].package

			if package and pending_release(package) then
				retry = true
			elseif package and not _current[package] then
				local record = { module = module, key = active[i].key }

				_current[package] = record
				record.id = manager:load(package, reference, function()
					if _current[package] == record then
						record.loaded = true
						mark(module, true)
						mod:info("host package %s loaded for %s", package, module)
					end
				end, true)
				loads[package] = { id = record.id, key = record.key }
			end
		end

		_dirty = retry or any_pending()
		_retry_at = _dirty and clock() + RETRY_INTERVAL or nil
	end

	function packages.release_when_idle()
		local loads = global_table(LOADS_KEY)
		local pending = global_table(RELEASES_KEY)

		for package, record in pairs(_current) do
			pending[#pending + 1] = { package = package, id = record.id, module = record.module }
			_current[package] = nil
			loads[package] = nil
		end

		_unconfirmed = false
		_dirty = true
	end

	local function drop_live_copies()
		if deps.drop_copies then
			deps.drop_copies()
		end
	end

	function packages.release_now()
		packages.release_when_idle()
		drop_live_copies()
		release_list(global_table(RELEASES_KEY))
		_held_since = nil
		_held_told = false
	end

	local function release_when_free(pending)
		if deps.in_use and deps.in_use() then
			if _held_told then
				return
			end

			local t = clock()

			_held_since = _held_since or t

			if t - _held_since < RELEASE_WAIT then
				return
			end

			mod:info("host packages: package copies were still live %d s after the level ended, so they are destroyed before the release", RELEASE_WAIT)
			drop_live_copies()

			if deps.in_use() then
				_held_told = true
				mod:info("host packages: package materials are still attached after the destroy pass, so the release waits for them")

				return
			end
		end

		_held_since = nil
		_held_told = false
		release_list(pending)
	end

	function packages.set_enabled(flag)
		local enabled = flag ~= false

		if enabled == _enabled then
			return
		end

		_enabled = enabled
		HOSTS.set_enabled(enabled)

		if enabled then
			if not _legacy_finish and not HOSTS.started() then
				start_hosts()
			end

			_dirty = true
			_retry_at = nil
		else
			packages.release_when_idle()
		end
	end

	local function prune_registrations()
		_prune_wanted = false

		local keep = deps.redirect_stocks and deps.redirect_stocks() or {}

		HOSTS.prune(keep)
	end

	function packages.update()
		if _legacy_finish and LEGACY.busy() then
			if clock() - _legacy_started > LEGACY_TIMEOUT then
				LEGACY.abort(late_legacy)
				_legacy_finish({ ok = false, reason_key = "legacy_install_timed_out", error = "timed out" })
			else
				LEGACY.update()
			end
		else
			if LEGACY.orphaned() and not HOSTS.busy() then
				LEGACY.update()
			end

			HOSTS.update()

			if not _failures_settled and HOSTS.ready() and (not _failures_check_at or clock() >= _failures_check_at) then
				tell_failures()
			end
		end

		local pending = rawget(_G, RELEASES_KEY)

		if pending and pending[1] and deps.no_world() then
			release_when_free(pending)
		elseif _held_since or _held_told then
			_held_since = nil
			_held_told = false
		end

		if _prune_wanted and not _legacy_finish and (HOSTS.ready() or not _enabled) and nothing_held() then
			prune_registrations()
		end

		if _unconfirmed then
			confirm_adopted()
		end

		local running = deps.gameplay_running() == true

		if running and (_dirty or not _was_running) and HOSTS.ready() and (not _was_running or not _retry_at or clock() >= _retry_at) then
			packages.acquire()
		end

		_was_running = running
	end

	function packages.hosts()
		return HOSTS
	end

	function packages.generation()
		return _generation
	end

	local function asset_ready(asset)
		for _, id in ipairs(asset_ids(asset)) do
			if _ready[id] then
				return true
			end
		end

		return false
	end

	function packages.resident(name, module)
		local asset = type(name) == "string" and string_match(name, RESOURCE_ROOT)

		if asset then
			return asset_ready(asset)
		end

		local manifest = module and manifest_of(module)

		if manifest and type(manifest.packages) == "table" then
			for _, owned in ipairs(manifest.packages) do
				if type(owned) == "string" and asset_ready(owned) then
					return true
				end
			end
		end

		return false
	end

	function packages.resource_ready(cache, key, type_name, name, module)
		local entry = cache[key]

		if entry and entry.generation == _generation then
			return entry.ready
		end

		local application = rawget(_G, "Application")
		local ready = packages.resident(name, module) and application ~= nil and application.can_get_resource(type_name, name) == true

		if entry then
			entry.generation = _generation
			entry.ready = ready
		else
			cache[key] = { generation = _generation, ready = ready }
		end

		return ready
	end

	local function ready_owned(entry, owner)
		local owners = entry and owner and entry.owners
		local owned = type(owners) == "table" and owners[owner]

		if type(owned) == "table" and _ready[owned.asset] then
			return owned
		end

		return nil
	end

	function packages.palette(effect_name, owner)
		local entry = CA_PALETTES[effect_name]
		local owned = ready_owned(entry, owner)

		if owned then
			owned.set = entry.set
		end

		return owned
	end

	function packages.live_copy(effect_name)
		local owned = ready_owned(CA_PALETTES[effect_name], "any")

		return owned and owned.names[1] or nil
	end

	function packages.slots(group)
		local owned = ready_owned(CA_PALETTES["slots:" .. group], "any")

		return owned and owned.names or nil
	end

	function packages.known(effect_name)
		return CA_PALETTES[effect_name] ~= nil
	end

	function packages.all()
		return CA_PALETTES
	end

	packages.adopt()

	return packages
end
