return function(mod, core, data_list)
	local AILMENT_SETTINGS = require("scripts/settings/ailments/ailment_settings")
	local BURN_IDS = { ailment_templates = AILMENT_SETTINGS.effect_templates }
	local UNPATCHED_BREED_PATTERNS = {}

	for _, data in ipairs(data_list) do
		for _, key in ipairs({ "soulblaze_buff", "flamer_buff" }) do
			BURN_IDS[key] = BURN_IDS[key] or data[key]
		end

		for _, key in ipairs({ "soulblaze_ailment", "flamer_ailment" }) do
			BURN_IDS[key] = BURN_IDS[key] or (data[key] and AILMENT_SETTINGS.effects[data[key]])
		end

		for _, pattern in ipairs(data.unpatched_breeds or {}) do
			UNPATCHED_BREED_PATTERNS[#UNPATCHED_BREED_PATTERNS + 1] = pattern
		end
	end

	local TIMING_VARIABLE = "offset_time_duration"
	local HUE_STEPS = 256
	local CODE_SCALE = 4
	local START_MAX_AGE = 1
	local SKULL_ARCHETYPE = "cryptic"

	local math_floor = math.floor
	local math_max = math.max
	local math_min = math.min
	local select = select
	local string_find = string.find

	local _starts = setmetatable({}, { __mode = "k" })
	local _failed = false

	mod:hook_safe(require("scripts/utilities/ailment"), "play_ailment_effect_template", function(unit, ailment_effect, optional_include_children, optional_custom_duration, optional_custom_offset_time)
		if (ailment_effect ~= BURN_IDS.soulblaze_ailment and ailment_effect ~= BURN_IDS.flamer_ailment) or not unit or not Unit.alive(unit) then
			return
		end

		local template = BURN_IDS.ailment_templates[ailment_effect]

		_starts[unit] = {
			start = World.time(Unit.world(unit)),
			offset = optional_custom_offset_time or template.offset_time,
			duration = optional_custom_duration or template.duration,
		}
	end)

	local function patched(unit)
		local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
		local breed = unit_data and unit_data:breed()
		local breed_name = breed and breed.name

		if not breed_name then
			return false
		end

		for i = 1, #UNPATCHED_BREED_PATTERNS do
			if string_find(breed_name, UNPATCHED_BREED_PATTERNS[i], 1, true) then
				return false
			end
		end

		return true
	end

	local function code_for(profile, t)
		local hue = profile.hue
		local saturation = profile.saturation

		if profile.mode == "rainbow" then
			local phase = t * core.RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
			saturation = 1
		end

		local hue_step = math_floor(hue * HUE_STEPS) % HUE_STEPS
		local saturation_step = math_floor(saturation * core.SATURATION_STEPS + 0.5)
		local brightness_step = math_max(core.MIN_BRIGHTNESS_STEP, math_min(core.MAX_BRIGHTNESS_STEP, math_floor(profile.brightness + 0.5)))

		return saturation_step * core.BURN_SATURATION + hue_step * 16 + brightness_step
	end

	local function apply_timing(unit, profile, timing)
		if not timing or not core.flag("burn_patch_served") or not patched(unit) then
			return
		end

		local code = code_for(profile, core.gameplay_time())

		Unit.set_vector3_for_materials(unit, TIMING_VARIABLE, Vector3(CODE_SCALE * code + timing.offset, timing.start, timing.duration), true)
	end

	local function soul_slot_for(profile, t)
		local hue = profile.hue or 0

		if profile.mode == "rainbow" then
			local phase = t * core.RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
		end

		local slots = core.soul_slots
		local names = core.effect_slots("soul")
		local index = math_floor(hue * #slots + 0.5) % #slots + 1

		return names and slots[index].usable and names[index] or nil
	end

	local function set_for(owner_unit)
		if not owner_unit then
			return nil
		end

		local spawn_manager = Managers.state.player_unit_spawn
		local player = spawn_manager and spawn_manager:owner(owner_unit)
		local skull = (player and player:archetype_name() == SKULL_ARCHETYPE) or (not player and core.is_servo_skull(owner_unit))

		if skull then
			return core.flag("skull_burn") and "skull" or nil
		end

		return core.flag("flamer_burn") and "flamer" or nil
	end

	local function flamer_profile_for(template_name, owner_unit)
		if template_name ~= BURN_IDS.flamer_buff then
			return nil
		end

		local set_id = set_for(owner_unit)
		local category = core.category_of_unit(owner_unit)

		if set_id == "skull" and category ~= "mine" then
			local spawn_manager = Managers.state.player_unit_spawn
			local player = spawn_manager and spawn_manager:owner(owner_unit)
			local local_player = Managers.player:local_player_safe(1)

			category = ((player and player == local_player) or core.skull_is_mine(owner_unit)) and "mine" or "team"
		end

		local profile = set_id and core.profile_for(set_id, category)

		if not profile or not profile.show or profile.mode == "stock" or profile.mode == "hidden" then
			return nil
		end

		return profile
	end

	local function take_start(unit)
		local timing = _starts[unit]

		_starts[unit] = nil

		if not timing or not Unit.alive(unit) or World.time(Unit.world(unit)) - timing.start > START_MAX_AGE then
			return nil
		end

		return timing
	end

	local function owner_from_args(...)
		for i = 1, select("#", ...), 2 do
			if select(i, ...) == "owner_unit" then
				return (select(i + 1, ...))
			end
		end

		return nil
	end

	local function soulblaze_slot(template, owner_unit)
		if not core.flag("soulblaze") or not template or template.name ~= BURN_IDS.soulblaze_buff then
			return nil
		end

		local profile = core.profile_for("staff", core.category_of_unit(owner_unit))

		if not profile or not profile.show or profile.mode == "stock" or profile.mode == "hidden" then
			return nil
		end

		return soul_slot_for(profile, core.gameplay_time())
	end

	local function failed(err)
		if not _failed then
			_failed = true
			mod:info("burn recolour disabled for this session: %s", core.with_traceback(err))
		end
	end

	local function spawn_choice(template, ...)
		local owner_unit = owner_from_args(...)

		return flamer_profile_for(template and template.name, owner_unit), soulblaze_slot(template, owner_unit)
	end

	mod:hook(CLASS.MinionBuffExtension, "_add_buff", function(func, self, template, t, from_server_correction, ...)
		if _failed then
			return func(self, template, t, from_server_correction, ...)
		end

		local chosen, profile, soul_spawn = pcall(spawn_choice, template, ...)

		if not chosen then
			failed(profile)

			return func(self, template, t, from_server_correction, ...)
		end

		local previous = core.swap_soul_spawn(soul_spawn)
		local ok, result = xpcall(core.call_with_burn_context, core.with_traceback, profile, func, self, template, t, from_server_correction, ...)

		core.swap_soul_spawn(previous)

		if not ok then
			error(result, 0)
		end

		return result
	end)

	local function buff_added(self, buff_instance)
		local name = buff_instance:template().name
		local unit = self._unit

		if not unit or (name ~= BURN_IDS.flamer_buff and name ~= BURN_IDS.soulblaze_buff) then
			return
		end

		local timing = take_start(unit)

		if not Unit.alive(unit) then
			return
		end

		if name == BURN_IDS.flamer_buff then
			local profile = flamer_profile_for(name, buff_instance:owner_unit())

			if profile then
				apply_timing(unit, profile, timing)
			end

			return
		end

		if not core.flag("soulblaze") then
			return
		end

		local profile = core.profile_for("staff", core.category_of_unit(buff_instance:owner_unit()))

		if not profile or not profile.show or profile.mode == "stock" then
			return
		end

		apply_timing(unit, profile, timing)
	end

	mod:hook(CLASS.MinionBuffExtension, "_on_add_buff", function(func, self, buff_instance)
		func(self, buff_instance)

		if _failed then
			return
		end

		local ok, err = pcall(buff_added, self, buff_instance)

		if not ok then
			failed(err)
		end
	end)

	return {}
end
