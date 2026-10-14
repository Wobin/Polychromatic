return function(mod)
	local COMPANION_SYSTEM = "companion_spawner_system"
	local NOT_A_COMPANION = {
		unit_is_companion = function()
			return false
		end,
	}

	local error = error
	local pcall = pcall

	mod:hook(CLASS.PackageSynchronizerHost, "_cleanup_owned_units", function(func, self, player)
		local script_unit = ScriptUnit
		local player_unit = player and player.player_unit

		if not player or (player_unit and script_unit.has_extension(player_unit, COMPANION_SYSTEM)) then
			return func(self, player)
		end

		local has_extension = script_unit.has_extension

		script_unit.has_extension = function(unit, system_name)
			if system_name == COMPANION_SYSTEM and unit == player_unit then
				return unit ~= nil and has_extension(unit, system_name) or NOT_A_COMPANION
			end

			return has_extension(unit, system_name)
		end

		local ok, err = pcall(func, self, player)

		script_unit.has_extension = has_extension

		if not ok then
			error(err, 0)
		end
	end)
end
