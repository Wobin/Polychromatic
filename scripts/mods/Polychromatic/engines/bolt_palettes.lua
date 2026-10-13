local math_floor = math.floor
local xpcall = xpcall
local error = error

return function(mod, core, data_list)
	local state = core.state
	local EFFECT_PACKAGES = core.EFFECT_PACKAGES
	local GLOW_SLOTS = core.glow_slots
	local GLOW_SOURCE_EFFECTS = core.glow_source_effects
	local GLOW_PALETTES = core.data("glow_particle_palettes")
	local profile_for = core.profile_for
	local player_category = core.player_category
	local resolve_set = core.resolve_set
	local gameplay_time = core.gameplay_time
	local resource_ready = core.resource_ready
	local with_traceback = core.with_traceback
	local effect_stat = core.effect_stat
	local RAINBOW_CYCLES_PER_SECOND = core.RAINBOW_CYCLES_PER_SECOND

	local _bolt_palette_ready = {}

	local function bolt_palette_name(effect_name, owner)
		local palette = EFFECT_PACKAGES.palette(effect_name, owner)

		if not palette or not owner then
			return nil
		end

		local profile = profile_for(resolve_set(palette.set, effect_name), owner)

		if not profile or profile.mode == "stock" or profile.mode == "hidden" then
			return nil
		end

		if not resource_ready(_bolt_palette_ready, palette, "particles", palette.names[1]) then
			return nil
		end

		local hue = profile.hue or 0

		if profile.mode == "rainbow" then
			local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
		end

		local names = palette.names

		return names[math_floor(hue * #names + 0.5) % #names + 1]
	end

	local _networked_resolve = 0

	local function resolve_bolt_particle(func, self, particle_alias, ...)
		local resolved, effect_name = func(self, particle_alias, ...)

		if resolved and _networked_resolve == 0 and EFFECT_PACKAGES.known(effect_name) then
			local previous_unit = state.staff_unit

			state.staff_unit = self._unit

			local ok, spawn_name = xpcall(bolt_palette_name, with_traceback, effect_name, player_category(self._unit))

			state.staff_unit = previous_unit

			if not ok then
				error(spawn_name, 0)
			end

			if spawn_name then
				effect_stat(effect_name).substituted = effect_stat(effect_name).substituted + 1

				return resolved, spawn_name
			end
		end

		return resolved, effect_name
	end

	mod:hook(CLASS.PlayerUnitVisualLoadoutExtension, "resolve_gear_particle", resolve_bolt_particle)
	mod:hook(CLASS.PlayerHuskVisualLoadoutExtension, "resolve_gear_particle", resolve_bolt_particle)

	local function call_networked(func, ...)
		_networked_resolve = _networked_resolve + 1

		local ok, a, b, c = xpcall(func, with_traceback, ...)

		_networked_resolve = _networked_resolve - 1

		if not ok then
			error(a, 0)
		end

		return a, b, c
	end

	for _, method in ipairs({ "spawn_moving_player_fx_alias", "spawn_gear_particle_effect_with_source", "_spawn_looping_particles" }) do
		mod:hook(CLASS.PlayerUnitFxExtension, method, call_networked)
	end

	local _palette_ready = {}

	local function palette_ready(entry)
		return resource_ready(_palette_ready, entry, "particles", entry.names[1])
	end

	local function glow_slot_for(effect_name, owner)
		local layer = GLOW_SOURCE_EFFECTS[effect_name]
		local palette = GLOW_PALETTES[effect_name] or EFFECT_PACKAGES.palette(effect_name, "hue")

		if layer then
			if owner ~= "mine" or not EFFECT_PACKAGES.slots(layer) then
				return nil
			end
		elseif not palette or not palette_ready(palette) then
			return nil
		elseif owner ~= "mine" and owner ~= "team" then
			return nil
		end

		local set_id = "las"

		if palette then
			set_id = resolve_set(palette.set or "las", effect_name)
		end

		local profile = profile_for(set_id, owner)

		if not profile or not profile.show or profile.mode == "stock" or profile.mode == "hidden" then
			return nil
		end

		local hue = profile.hue or 0

		if profile.mode == "rainbow" then
			local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
		end

		if palette then
			local names = palette.names

			return names[math_floor(hue * #names + 0.5) % #names + 1]
		end

		local list = GLOW_SLOTS[layer]
		local index = math_floor(hue * #list + 0.5) % #list + 1

		return list[index].usable and EFFECT_PACKAGES.slots(layer)[index] or nil
	end

	return {
		palette_name = bolt_palette_name,
		glow_slot_for = glow_slot_for,
	}
end
