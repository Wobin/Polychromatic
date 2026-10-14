return function(mod, module_data, modules)
	local CA_PALETTES = module_data("ca_palettes")
	local CA_ASSETS = module_data("ca_assets")
	local INSTALLER = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/package_install")(mod, modules)
	local PACKAGE_REFERENCE = "Polychromatic"
	local OPT_OUT = "effect_packages_removed"

	local pairs = pairs
	local tostring = tostring

	local _ready = {}
	local _load_ids = {}
	local _requested = false
	local _generation = 0
	local _relabel = nil
	local packages = {}

	local function asset_ids()
		local assets = {}

		for i = 1, #CA_ASSETS do
			assets[CA_ASSETS[i]] = true
		end

		return assets
	end

	local function say(key, detail)
		if detail then
			mod:echo("%s (%s)", mod:localize(key), tostring(detail))
		else
			mod:echo("%s", mod:localize(key))
		end
	end

	function packages.startup(after)
		local function finish()
			if after then
				after()
			end
		end

		if mod:get(OPT_OUT) == true then
			INSTALLER.startup(false, function(result)
				if result.restored then
					say("packages_removed")
				end

				finish()
			end)

			return
		end

		INSTALLER.startup(true, function(result)
			if result.no_modules then
				say("modules_none")
			elseif result.modules_changed then
				mod:echo("%s (%s). %s", mod:localize("modules_changed"), tostring(result.modules_changed), mod:localize("restart_to_apply"))
			elseif result.installed then
				say("packages_installed")
			elseif not result.ok then
				say("packages_failed", result.error)
			end

			finish()
		end)
	end

	function packages.update()
		INSTALLER.update()
	end

	function packages.busy()
		return INSTALLER.busy()
	end

	function packages.set_relabel(relabel)
		_relabel = relabel
	end

	function packages.render_settings()
		return INSTALLER.render_settings()
	end

	function packages.label_key()
		if INSTALLER.busy() then
			return "checking"
		end

		local opted_out = mod:get(OPT_OUT) == true

		for i = 1, #CA_ASSETS do
			if Application.can_get_resource("package", INSTALLER.package_name(CA_ASSETS[i])) then
				return opted_out and "removing" or "installed"
			end
		end

		local state

		if INSTALLER.async() then
			state = INSTALLER.last_state()

			if not state then
				INSTALLER.state_then(function()
					if _relabel then
						_relabel()
					end
				end)

				return "checking"
			end
		else
			state = INSTALLER.state()
		end

		return (not opted_out and state.ok and state.applied) and "installing" or "absent"
	end

	function packages.toggle(after)
		local function finish()
			if INSTALLER.async() then
				INSTALLER.state_then(function()
					if after then
						after()
					end
				end)
			elseif after then
				after()
			end
		end

		if INSTALLER.busy() then
			return
		end

		INSTALLER.state_then(function(state)
			if not state.ok then
				say("packages_failed", state.error)

				if after then
					after()
				end

				return
			end

			if state.applied then
				mod:set(OPT_OUT, true)

				INSTALLER.remove_then(state, function(result)
					if result.deferred then
						say("packages_remove_next_launch")
					elseif result.ok then
						say("packages_removed")
					else
						say("packages_failed", result.error)
					end

					finish()
				end)

				return
			end

			if not modules or #modules == 0 then
				say("packages_nothing_to_install")

				if after then
					after()
				end

				return
			end

			mod:set(OPT_OUT, false)

			INSTALLER.install_then(false, state, function(result)
				if result.installed then
					say("packages_installed")
				elseif not result.ok then
					say("packages_failed", result.error)
				end

				finish()
			end)
		end)
	end

	function packages.acquire()
		if _requested or not INSTALLER.live() then
			return
		end

		local manager = Managers and Managers.package

		if not manager then
			return
		end

		_requested = true

		for asset_id in pairs(asset_ids()) do
			local package_name = INSTALLER.package_name(asset_id)

			if Application.can_get_resource("package", package_name) then
				_load_ids[asset_id] = manager:load(package_name, PACKAGE_REFERENCE, function()
					_ready[asset_id] = true
					_generation = _generation + 1
					mod:info("effect package %s loaded", package_name)
				end, true)
			else
				mod:info("effect package %s is not known to the game; built-in effect copies are used", package_name)
			end
		end
	end

	function packages.release()
		local manager = Managers and Managers.package

		for asset_id, id in pairs(_load_ids) do
			if manager then
				manager:release(id)
			end

			_load_ids[asset_id] = nil
		end

		for asset_id in pairs(_ready) do
			_ready[asset_id] = nil
		end

		_requested = false
	end

	function packages.generation()
		return _generation
	end

	function packages.palette(effect_name, owner)
		local entry = CA_PALETTES[effect_name]
		local owned = entry and owner and entry.owners[owner]

		if owned and _ready[owned.asset] then
			owned.set = entry.set

			return owned
		end

		return nil
	end

	function packages.live_copy(effect_name)
		local entry = CA_PALETTES[effect_name]
		local owned = entry and entry.owners.any

		if owned and _ready[owned.asset] then
			return owned.names[1]
		end

		return nil
	end

	function packages.slots(group)
		local entry = CA_PALETTES["slots:" .. group]
		local owned = entry and entry.owners.any

		if owned and _ready[owned.asset] then
			return owned.names
		end

		return nil
	end

	function packages.known(effect_name)
		return CA_PALETTES[effect_name] ~= nil
	end

	function packages.all()
		return CA_PALETTES
	end

	return packages
end
