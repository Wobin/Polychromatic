local SLOT_SCRIPT_SPAWNERS = {
	ForceWeaponBlockEffects = { "update" },
	ForceWeaponWindSlashStageEffects = { "update", "wield" },
	ForceWeaponWindSlashActivationEffects = { "update_unit_position" },
	PlasmagunOverheatEffects = { "update" },
	ForceStaffAoeTargetingEffects = { "update" },
	PsykerSingleTargetEffects = { "update" },
	ChainLightningTargetEffects = { "update" },
}

local math_floor = math.floor
local math_max = math.max
local World = World
local World_are_particles_playing = World.are_particles_playing
local World_destroy_particles = World.destroy_particles
local World_has_particles_material = World.has_particles_material
local World_set_particles_material_scalar = World.set_particles_material_scalar
local World_set_particles_material_vector3 = World.set_particles_material_vector3
local World_stop_spawning_particles = World.stop_spawning_particles

return function(mod, core, data_list)
	local state = core.state
	local ENGINE = core.engines
	local EFFECT_PACKAGES = core.EFFECT_PACKAGES
	local BURN_PALETTES = core.burn_palettes
	local BURN_PALETTE_SETS = core.burn_palette_sets or {}
	local profile_for = core.profile_for
	local player_category = core.player_category
	local category_of_unit = core.category_of_unit
	local skull_is_mine = core.skull_is_mine
	local resolve_set = core.resolve_set
	local gameplay_time = core.gameplay_time
	local hsv_to_rgb = core.hsv_to_rgb
	local resource_ready = core.resource_ready
	local effect_stat = core.effect_stat
	local redshift_owns_sniper = core.redshift_owns_sniper
	local register_owner_hook = core.register_owner_hook
	local call_with_spawn_context = core.call_with_spawn_context
	local call_with_owner_unit = core.call_with_owner_unit
	local RAINBOW_CYCLES_PER_SECOND = core.RAINBOW_CYCLES_PER_SECOND
	local STOCK_BRIGHTNESS_STEP = core.STOCK_BRIGHTNESS_STEP
	local MIN_BRIGHTNESS_STEP = core.MIN_BRIGHTNESS_STEP
	local MAX_BRIGHTNESS_STEP = core.MAX_BRIGHTNESS_STEP
	local SATURATION_STEPS = core.SATURATION_STEPS
	local SKULL_FLAMER_SETTINGS = "scripts/settings/companion/companion_servo_skull_flamer_settings"
	local SKULL_FLAMER_TEMPLATE = "scripts/settings/fx/effect_templates/companion_servo_skull_flamer"
	local SKULL_FLAMER_RANGE = nil

	local VARIABLE = "lighting_far_range"
	local STOCK_VALUE = 1000
	local HUE_STEPS = 1024
	local STEPS = {
		code_divisor = 16384,
		pending_tint_frames = 30,
		package_prune_at = 512,
	}
	local MAX_CLOUDS = 16
	local DIRECT_CLOUD = "beam"
	local EFFECT_TABLES = {
		direct = core.data("direct_effects"),
		spawn_vector_clouds = core.data("spawn_vector_clouds"),
		flash = core.data("flash_effects"),
		encoded = core.data("encoded_effects"),
		unreachable = core.data("unreachable_effects"),
	}
	local CLOUDS = {}

	for i = 1, MAX_CLOUDS do
		CLOUDS[i] = "polychromatic_jet_" .. i
	end

	local function encoded_value(profile, t)
		local mode = profile.mode

		if mode == "stock" then
			return STOCK_VALUE
		end

		local hue = profile.hue
		local saturation = profile.saturation

		if mode == "rainbow" then
			local phase = t * RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
			saturation = 1
		end

		local hue_step = math_floor(hue * HUE_STEPS) % HUE_STEPS
		local saturation_step = math_floor(saturation * SATURATION_STEPS + 0.5)
		local brightness_step = math_floor(profile.brightness + 0.5)

		if brightness_step < MIN_BRIGHTNESS_STEP then
			brightness_step = MIN_BRIGHTNESS_STEP
		elseif brightness_step > MAX_BRIGHTNESS_STEP then
			brightness_step = MAX_BRIGHTNESS_STEP
		end

		return STOCK_VALUE + saturation_step + (hue_step * 16 + brightness_step) / STEPS.code_divisor
	end

	local _cloud_cache = {}
	local _cloud_misses = {}
	local _spawn_serial = {}

	local function forget_particle(particle_id)
		_cloud_cache[particle_id] = nil
		_cloud_misses[particle_id] = nil
		_spawn_serial[particle_id] = (_spawn_serial[particle_id] or 0) + 1
	end

	local function tint(world, particle_id, value)
		if not state.gameplay_running then
			return false
		end

		if not World_are_particles_playing(world, particle_id) then
			return true
		end

		local misses = _cloud_misses[particle_id]

		if misses and misses >= STEPS.pending_tint_frames then
			return false
		end

		local cached = _cloud_cache[particle_id]

		if cached then
			local hits = 0

			for i = 1, #cached do
				local cloud = cached[i]

				if World_has_particles_material(world, particle_id, cloud) then
					World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)

					hits = hits + 1
				end
			end

			if hits == #cached then
				return true
			end
		end

		local found = nil

		for i = 1, MAX_CLOUDS do
			local cloud = CLOUDS[i]

			if World_has_particles_material(world, particle_id, cloud) then
				World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)

				found = found or {}
				found[#found + 1] = cloud
			end
		end

		_cloud_cache[particle_id] = found

		if found then
			_cloud_misses[particle_id] = nil
		else
			_cloud_misses[particle_id] = (misses or 0) + 1
		end

		return found ~= nil
	end

	local function profile_rgb(profile, t)
		local hue = profile.hue
		local saturation = profile.saturation

		if profile.mode == "rainbow" then
			local phase = t * RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
			saturation = 1
		end

		return hsv_to_rgb(hue, saturation, profile.brightness / STOCK_BRIGHTNESS_STEP)
	end

	local function tint_direct(world, particle_id, variable, profile)
		if not state.gameplay_running then
			return false
		end

		if profile.mode == "stock" or not World_are_particles_playing(world, particle_id) then
			return true
		end

		if not World_has_particles_material(world, particle_id, DIRECT_CLOUD) then
			return false
		end

		local r, g, b = profile_rgb(profile, gameplay_time())

		World_set_particles_material_vector3(world, particle_id, DIRECT_CLOUD, variable, Vector3(r, g, b))

		return true
	end

	local function tint_mixed(world, particle_id, profile, vector_clouds)
		if not state.gameplay_running then
			return false
		end

		if not World_are_particles_playing(world, particle_id) then
			return true
		end

		local t = gameplay_time()
		local value = encoded_value(profile, t)
		local r, g, b = profile_rgb(profile, t)
		local written = 0

		for i = 1, MAX_CLOUDS do
			local cloud = CLOUDS[i]

			if World_has_particles_material(world, particle_id, cloud) then
				local vector_variable = vector_clouds[cloud]

				if type(vector_variable) == "table" then
					for j = 1, #vector_variable do
						World_set_particles_material_vector3(world, particle_id, cloud, vector_variable[j], Vector3(r, g, b))
					end
				elseif vector_variable then
					World_set_particles_material_vector3(world, particle_id, cloud, vector_variable, Vector3(r, g, b))
				else
					World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)
				end

				written = written + 1
			end
		end

		return written > 0
	end

	local function apply_spawn(world, particle_id, profile, variable, effect_name)
		local vector_clouds = effect_name and EFFECT_TABLES.spawn_vector_clouds[effect_name]

		if profile.mode == "hidden" then
			World_stop_spawning_particles(world, particle_id)

			return true
		elseif not profile.show or profile.mode == "stock" then
			return true
		elseif variable then
			return tint_direct(world, particle_id, variable, profile)
		elseif vector_clouds then
			return tint_mixed(world, particle_id, profile, vector_clouds)
		end

		return tint(world, particle_id, encoded_value(profile, gameplay_time()))
	end

	local function apply_flash(world, particle_id, flash, profile)
		if not state.gameplay_running then
			return false
		end

		if profile.mode == "hidden" then
			World_stop_spawning_particles(world, particle_id)

			return true
		end

		if not profile.show or profile.mode == "stock" or not World_are_particles_playing(world, particle_id) then
			return true
		end

		local r, g, b = profile_rgb(profile, gameplay_time())
		local written = 0

		for i = 1, flash.clouds do
			local cloud = CLOUDS[i]

			if World_has_particles_material(world, particle_id, cloud) then
				World_set_particles_material_vector3(world, particle_id, cloud, flash.variable, Vector3(r, g, b))

				written = written + 1
			end
		end

		return written > 0
	end

	local _pending_tints = {}

	local function apply_or_defer(stat, world, particle_id, apply, first, second, third)
		stat.seen = stat.seen + 1

		if apply(world, particle_id, first, second, third) then
			stat.applied = stat.applied + 1

			return
		end

		local world_manager = Managers.world
		local world_name = world_manager and world_manager:world_name(world)

		if not world_name then
			stat.expired = stat.expired + 1

			return
		end

		stat.deferred = stat.deferred + 1

		_pending_tints[#_pending_tints + 1] = {
			stat = stat,
			world = world,
			world_name = world_name,
			particle_id = particle_id,
			serial = _spawn_serial[particle_id],
			apply = apply,
			first = first,
			second = second,
			third = third,
			frames = 0,
		}
	end

	local function retry_pending_tints()
		if not state.gameplay_running then
			return
		end

		local world_manager = Managers.world

		for i = #_pending_tints, 1, -1 do
			local entry = _pending_tints[i]

			entry.frames = entry.frames + 1

			if not world_manager or world_manager:world(entry.world_name) ~= entry.world or _spawn_serial[entry.particle_id] ~= entry.serial then
				entry.stat.expired = entry.stat.expired + 1
				table.remove(_pending_tints, i)
			elseif entry.apply(entry.world, entry.particle_id, entry.first, entry.second, entry.third) then
				entry.stat.late = entry.stat.late + 1
				table.remove(_pending_tints, i)
			elseif entry.frames >= STEPS.pending_tint_frames then
				entry.stat.expired = entry.stat.expired + 1
				table.remove(_pending_tints, i)
			end
		end
	end

	local function clear_pending_tints()
		for i = #_pending_tints, 1, -1 do
			_pending_tints[i] = nil
		end

		for particle_id in pairs(_cloud_cache) do
			_cloud_cache[particle_id] = nil
		end

		for particle_id in pairs(_cloud_misses) do
			_cloud_misses[particle_id] = nil
		end
	end

	local _burn_palette_ready = {}

	local function burn_palette_name(effect_name)
		local profile = BURN_PALETTES[effect_name] and state.spawn_context_active and state.spawn_context[effect_name]

		if not profile or profile.mode == "stock" or profile.mode == "hidden" then
			return nil
		end

		local palettes = BURN_PALETTE_SETS[profile.set]
		local palette = palettes and palettes[effect_name]

		if not palette or not resource_ready(_burn_palette_ready, palette, "particles", palette[1]) then
			return nil
		end

		local hue = profile.hue or 0

		if profile.mode == "rainbow" then
			local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
		end

		return palette[math_floor(hue * #palette + 0.5) % #palette + 1]
	end

	local _package_names = {}
	local _package_particles = {}

	for _, entry in pairs(core.palettes or {}) do
		for _, owned in pairs(type(entry) == "table" and type(entry.owners) == "table" and entry.owners or {}) do
			for _, name in ipairs(type(owned) == "table" and owned.names or {}) do
				_package_names[name] = true
			end
		end
	end

	for _, palettes in pairs(BURN_PALETTE_SETS) do
		for _, list in pairs(palettes) do
			for _, name in ipairs(list) do
				_package_names[name] = true
			end
		end
	end

	for _, entry in pairs(core.data("glow_particle_palettes") or {}) do
		for _, name in ipairs(type(entry) == "table" and entry.names or {}) do
			_package_names[name] = true
		end
	end

	local function prune_package_particles(world, tracked)
		local live = 0

		for particle_id in pairs(tracked.ids) do
			if World_are_particles_playing(world, particle_id) then
				live = live + 1
			else
				tracked.ids[particle_id] = nil
			end
		end

		tracked.count = live
		tracked.prune_at = math_max(STEPS.package_prune_at, live * 2)

		return live
	end

	local function track_package_particle(world, particle_id, packaged)
		local tracked = _package_particles[world]

		if not packaged then
			if tracked and tracked.ids[particle_id] then
				tracked.ids[particle_id] = nil
				tracked.count = tracked.count - 1
			end

			return
		end

		if not tracked then
			local world_manager = Managers.world

			tracked = { world_name = world_manager and world_manager:world_name(world), ids = {}, count = 0, prune_at = STEPS.package_prune_at }
			_package_particles[world] = tracked
		end

		if not tracked.ids[particle_id] then
			tracked.ids[particle_id] = true
			tracked.count = tracked.count + 1

			if tracked.count >= tracked.prune_at then
				prune_package_particles(world, tracked)
			end
		end
	end

	local function forget_dead_worlds(world_manager)
		for world, tracked in pairs(_package_particles) do
			if world_manager and tracked.world_name and world_manager:world(tracked.world_name) ~= world then
				_package_particles[world] = nil
			end
		end
	end

	local function package_particles_in_use()
		local world_manager = Managers.world

		forget_dead_worlds(world_manager)

		for world, tracked in pairs(_package_particles) do
			if not world_manager or not tracked.world_name or prune_package_particles(world, tracked) > 0 then
				return true
			end
		end

		return false
	end

	local function no_substitute()
		return nil
	end

	local BOLT_PALETTES = ENGINE.bolt_palettes
	local glow_slot_for = BOLT_PALETTES and BOLT_PALETTES.glow_slot_for or no_substitute
	local bolt_palette_name = BOLT_PALETTES and BOLT_PALETTES.palette_name or no_substitute

	local _scene_light_failed = false

	local function ownerless_skull_category(position)
		local player_manager = Managers.player
		local local_player = player_manager and player_manager:local_player_safe(1)
		local players = position and player_manager and player_manager:players()
		local category, nearest = "team", 9

		for _, player in pairs(players or {}) do
			local player_unit = player.player_unit
			local spawner = player_unit and Unit.alive(player_unit) and ScriptUnit.has_extension(player_unit, "companion_spawner_system")
			local units = spawner and spawner:companion_units()

			for i = 1, units and #units or 0 do
				local unit = units[i]

				if Unit.alive(unit) then
					local distance = Vector3.distance_squared(Unit.world_position(unit, 1), position)

					if distance < nearest then
						category, nearest = player == local_player and "mine" or "team", distance
					end
				end
			end
		end

		return category
	end

	mod:hook(World, "create_particles", function(func, world, effect_name, ...)
		local owner = state.spawn_owner

		if not owner and ENGINE.pools then
			owner = ENGINE.pools.owner(effect_name, (...))
		end

		local spawn_name = (effect_name == "content/fx/particles/enemies/buff_warpfire" and state.soul_spawn) or glow_slot_for(effect_name, owner) or burn_palette_name(effect_name) or bolt_palette_name(effect_name, owner or "enemy") or EFFECT_PACKAGES.live_copy(effect_name) or effect_name
		local particle_id = func(world, spawn_name, ...)

		if particle_id and ENGINE.pools then
			ENGINE.pools.remember(effect_name, state.spawn_owner, (...))
		end

		if particle_id and ENGINE.scene_lights and not _scene_light_failed then
			ENGINE.scene_lights.spawn_owner = owner
			local ok, err = pcall(ENGINE.scene_lights.on_spawn, world, spawn_name, ...)

			if not ok then
				_scene_light_failed = true
				mod:info("scene light disabled for this session: %s", tostring(err))
			end
		end

		if particle_id then
			forget_particle(particle_id)
			track_package_particle(world, particle_id, spawn_name ~= effect_name or _package_names[spawn_name] == true)
		end

		if spawn_name ~= effect_name then
			local stat = effect_stat(effect_name)

			stat.substituted = stat.substituted + 1
		end

		if not particle_id then
			return particle_id
		end

		if EFFECT_TABLES.unreachable[effect_name] or BURN_PALETTES[effect_name] then
			return particle_id
		end

		local profile = state.spawn_context_active and state.spawn_context[effect_name]

		if profile then
			apply_or_defer(effect_stat(effect_name, profile.set, profile.category), world, particle_id, apply_spawn, profile, nil, effect_name)

			return particle_id
		end

		local flash = EFFECT_TABLES.flash[effect_name]

		if flash then
			if not redshift_owns_sniper() then
				profile = profile_for("sniper", "enemy")

				if profile then
					apply_or_defer(effect_stat(effect_name, "sniper", "enemy"), world, particle_id, apply_flash, flash, profile)
				end
			end

			return particle_id
		end

		local variable = EFFECT_TABLES.direct[effect_name]
		local set_id = variable and "las" or resolve_set(EFFECT_TABLES.encoded[effect_name], effect_name)

		if not set_id then
			return particle_id
		end

		if set_id == "sniper" and redshift_owns_sniper() then
			return particle_id
		end

		if not owner and set_id == "skull_las" then
			owner = ownerless_skull_category((...))
		end

		owner = owner or "enemy"
		profile = profile_for(set_id, owner)

		if profile then
			apply_or_defer(effect_stat(effect_name, set_id, owner), world, particle_id, apply_spawn, profile, variable, effect_name)
		end

		return particle_id
	end)

	register_owner_hook(CLASS.PlayerUnitFxExtension, "_create_particles_wrapper", function(self)
		return self._unit, player_category(self._unit)
	end)

	register_owner_hook(CLASS.PlayerUnitFxExtension, "_add_moving_vfx", function(self)
		return self._unit, player_category(self._unit)
	end)

	register_owner_hook(CLASS.PlayerUnitFxExtension, "_spawn_unit_fx_line", function(self)
		return self._unit, player_category(self._unit)
	end)

	register_owner_hook(CLASS.ProjectileFxExtension, "start_fx", function(self)
		return self._owner_unit, category_of_unit(self._owner_unit)
	end)

	register_owner_hook(CLASS.ProjectileFxExtension, "start_and_link_vfx", function(self)
		return self._owner_unit, category_of_unit(self._owner_unit)
	end)

	register_owner_hook(CLASS.FxSystem, "play_impact_fx", function(self, impact_fx, hit_position, attack_direction, source_parameters, attacking_unit)
		return attacking_unit, category_of_unit(attacking_unit)
	end)

	register_owner_hook(CLASS.FxSystem, "play_surface_impact_fx", function(self, hit_position, hit_direction, source_parameters, attacking_unit)
		return attacking_unit, category_of_unit(attacking_unit)
	end)

	register_owner_hook(CLASS.FxSystem, "play_shotshell_surface_impact_fx", function(self, fire_position, hit_positions, hit_normals, source_parameters, attacking_unit)
		return state.staff_unit, category_of_unit(attacking_unit)
	end)

	register_owner_hook(CLASS.MinionFxExtension, "_trigger_inventory_vfx", function(self)
		return state.staff_unit, category_of_unit(self._unit)
	end)

	register_owner_hook(CLASS.MinionFxExtension, "_trigger_unit_line_fx", function(self)
		return state.staff_unit, category_of_unit(self._unit)
	end)

	local _slot_script_owners = setmetatable({}, { __mode = "k" })
	local _slot_script_units = setmetatable({}, { __mode = "k" })

	local function extension_unit(extension)
		local unit = type(extension) == "table" and not rawget(extension, "__deleted") and extension._unit

		return unit or nil
	end

	local function loadout_holder(slot_script)
		local player_manager = Managers.player

		if not player_manager or rawget(player_manager, "__deleted") or not player_manager.players then
			return nil
		end

		for _, player in pairs(player_manager:players() or {}) do
			local unit = player.player_unit
			local extension = unit and Unit.alive(unit) and ScriptUnit.has_extension(unit, "visual_loadout_system")
			local by_slot = extension and extension._wieldable_slot_scripts

			if type(by_slot) == "table" then
				for _, scripts in pairs(by_slot) do
					for i = 1, #scripts do
						if scripts[i] == slot_script then
							return unit
						end
					end
				end
			end
		end

		return nil
	end

	local function slot_script_unit(slot_script)
		local unit = _slot_script_units[slot_script]

		if unit == nil then
			unit = slot_script._owner_unit or extension_unit(slot_script._fx_extension) or extension_unit(slot_script._visual_loadout_extension) or loadout_holder(slot_script) or false
			_slot_script_units[slot_script] = unit
		end

		return unit or nil
	end

	local function slot_script_category(slot_script)
		local category = _slot_script_owners[slot_script]

		if category == nil then
			category = player_category(slot_script_unit(slot_script))
			_slot_script_owners[slot_script] = category
		end

		return category
	end

	local function remember_slot_script(self, context)
		_slot_script_units[self] = context and context.owner_unit or nil
		_slot_script_owners[self] = nil
	end

	local function slot_script_owner(self)
		local category = slot_script_category(self)

		return slot_script_unit(self), category
	end

	local function track_link_spawn(self)
		local effects = self._effects
		local entry = effects and effects[self._num_effects]
		local effect_id = entry and entry.effect_id

		if effect_id then
			forget_particle(effect_id)
		end
	end

	local FxData = CLASS.FxData

	if type(FxData) == "string" or type(FxData) == "table" and type(FxData.spawn_vfx) == "function" and type(FxData.spawn_vfx_world_position) == "function" then
		mod:hook_safe(FxData, "spawn_vfx", track_link_spawn)
		mod:hook_safe(FxData, "spawn_vfx_world_position", track_link_spawn)
	else
		mod:info("live tint: chain lightning link spawns are not tracked, FxData spawn methods not found")
	end

	local DECAL_SWAP = ENGINE.decal_swap
	local SLOT_SCRIPT_AFTER = {
		ForceStaffAoeTargetingEffects = DECAL_SWAP and DECAL_SWAP.recolour or nil,
	}

	for class_name, methods in pairs(SLOT_SCRIPT_SPAWNERS) do
		mod:hook_safe(CLASS[class_name], "init", remember_slot_script)

		for i = 1, #methods do
			register_owner_hook(CLASS[class_name], methods[i], slot_script_owner, SLOT_SCRIPT_AFTER[class_name])
		end
	end

	local function flamer_set(self)
		return self._weapon_actions.action_shoot_flame and "staff" or "flamer"
	end

	local function flamer_profile(self)
		local fx_extension = self._fx_extension

		return profile_for(flamer_set(self), player_category(fx_extension and fx_extension._unit))
	end

	mod:hook(CLASS.FlamerGasEffects, "_update_impact_effects", function(func, self, dt, t)
		local profile = flamer_profile(self)

		if not profile then
			return func(self, dt, t)
		end

		state.spawn_context[flamer_set(self) == "staff" and "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay" or "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay"] = profile
		state.spawn_context_active = true

		local fx_extension = self._fx_extension

		return call_with_owner_unit(fx_extension and fx_extension._unit, profile.category, call_with_spawn_context, func, self, dt, t)
	end)

	local _hidden_streams = setmetatable({}, { __mode = "k" })

	local function hide_stream(owner, world, stream_effect_id)
		if _hidden_streams[owner] ~= stream_effect_id then
			World_stop_spawning_particles(world, stream_effect_id)

			_hidden_streams[owner] = stream_effect_id
		end
	end

	local function flamer_stream_light(self)
		local fx_extension = self._fx_extension
		local from_pos = Matrix4x4.translation(fx_extension:vfx_spawner_pose(self._fx_source_name))
		local finder = self._action_module_position_finder_component
		local to_pos = finder.position_valid and finder.position or from_pos + Quaternion.forward(self._first_person_component.rotation) * self._action_flamer_gas_component.range

		ENGINE.scene_lights.stream(self, self._world, from_pos, to_pos, flamer_set(self), player_category(fx_extension._unit))
	end

	mod:hook_safe(CLASS.FlamerGasEffects, "_update_effects", function(self, dt, t)
		local stream_effect_id = self._stream_effect_id

		if not stream_effect_id then
			_hidden_streams[self] = nil
		elseif ENGINE.scene_lights and not _scene_light_failed then
			local ok, err = pcall(flamer_stream_light, self)

			if not ok then
				_scene_light_failed = true
				mod:info("scene light disabled for this session: %s", tostring(err))
			end
		end

		local profile = flamer_profile(self)

		if not profile then
			return
		end

		local world = self._world

		if profile.mode == "hidden" then
			if stream_effect_id then
				hide_stream(self, world, stream_effect_id)
			end

			return
		end

		if not profile.show or profile.mode == "stock" then
			return
		end

		local value = encoded_value(profile, t)

		if stream_effect_id then
			tint(world, stream_effect_id, value)
		end

		local stopped = self._stoped_particles

		for i = 1, #stopped do
			tint(world, stopped[i], value)
		end
	end)

	local function skull_stream_light(template_data, template_context, owner)
		local from_pos = Unit.world_position(template_data.attachment_unit, template_data.attachment_node)
		local game_session, game_object_id = template_data.game_session, template_data.game_object_id
		local to_pos = GameSession.game_object_field(game_session, game_object_id, "fx_position_valid") and GameSession.game_object_field(game_session, game_object_id, "fx_impact_position")

		ENGINE.scene_lights.stream(template_data, template_context.world, from_pos, to_pos or from_pos + Quaternion.forward(Unit.world_rotation(template_data.unit, 1)) * SKULL_FLAMER_RANGE, "skull", owner)
	end

	local function skull_update(template_data, template_context, dt, t)
		local stream_effect_id = template_data.stream_effect_id

		if not stream_effect_id then
			_hidden_streams[template_data] = nil

			return
		end

		local owner = skull_is_mine(template_data.unit) and "mine" or "team"

		if ENGINE.scene_lights and not _scene_light_failed then
			local ok, err = pcall(skull_stream_light, template_data, template_context, owner)

			if not ok then
				_scene_light_failed = true
				mod:info("scene light disabled for this session: %s", tostring(err))
			end
		end

		local profile = profile_for("skull", owner)

		if not profile then
			return
		end

		if profile.mode == "hidden" then
			hide_stream(template_data, template_context.world, stream_effect_id)

			return
		end

		if not profile.show or profile.mode == "stock" then
			return
		end

		tint(template_context.world, stream_effect_id, encoded_value(profile, t))
	end

	core.after_boot("live_tint", function()
		SKULL_FLAMER_RANGE = require(SKULL_FLAMER_SETTINGS).vfx.max_range
		mod:hook_safe(require(SKULL_FLAMER_TEMPLATE), "update", skull_update)
	end)

	local function drop_package_particles()
		local world_manager = Managers.world
		local live_manager = world_manager and not rawget(world_manager, "__deleted") and world_manager or nil
		local dropped = 0

		for world, tracked in pairs(_package_particles) do
			if live_manager and tracked.world_name and live_manager:world(tracked.world_name) == world then
				for particle_id in pairs(tracked.ids) do
					if World_are_particles_playing(world, particle_id) then
						World_destroy_particles(world, particle_id)
						dropped = dropped + 1
					end
				end
			end

			_package_particles[world] = nil
		end

		return dropped
	end

	return {
		update = function()
			if _pending_tints[1] then
				retry_pending_tints()
			end
		end,
		clear = function()
			clear_pending_tints()
			forget_dead_worlds(Managers.world)
		end,
		in_use = package_particles_in_use,
		drop_package_particles = drop_package_particles,
	}
end
