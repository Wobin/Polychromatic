--[[
	Name: Polychromatic
	Author: Wobin
	Date: 05/10/2026
]]--

local mod = get_mod("Polychromatic")
mod.version = mod.get_metadata and mod:get_metadata("version") or "unknown"

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local World = World
local World_are_particles_playing = World.are_particles_playing
local World_has_particles_material = World.has_particles_material
local World_set_particles_material_scalar = World.set_particles_material_scalar
local World_set_particles_material_vector3 = World.set_particles_material_vector3
local World_stop_spawning_particles = World.stop_spawning_particles
local get_mod = get_mod
local REDIRECT_DATA = "Polychromatic/scripts/mods/Polychromatic/redirects/"
local EFFECT_DATA = "Polychromatic/scripts/mods/Polychromatic/effects/"

local REDIRECTS = mod:io_dofile(REDIRECT_DATA .. "redirects")

local LAS_REDIRECTS = mod:io_dofile(REDIRECT_DATA .. "las_redirects")

for i = 1, #LAS_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = LAS_REDIRECTS[i]
end

local SNIPER_FLASH_REDIRECTS = mod:io_dofile(REDIRECT_DATA .. "sniper_flash_redirects")

for i = 1, #SNIPER_FLASH_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = SNIPER_FLASH_REDIRECTS[i]
end

local BURN_REDIRECTS = mod:io_dofile(REDIRECT_DATA .. "burn_redirects")

for i = 1, #BURN_REDIRECTS do
	REDIRECTS[#REDIRECTS + 1] = BURN_REDIRECTS[i]
end

local MIN_BRIGHTNESS_STEP = 1
local STOCK_BRIGHTNESS_STEP = 8
local MAX_BRIGHTNESS_STEP = 15

local function redirect_served(state)
	return state == "active" or state == "shared" or state == "compatible"
end

local SOUL_SLOTS = mod:io_dofile(REDIRECT_DATA .. "soul_slots")
local baked = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/Polychromatic_bake")({
	mod = mod,
	redirect_data = REDIRECT_DATA,
	effect_data = EFFECT_DATA,
	redirects = REDIRECTS,
	soul_slots = SOUL_SLOTS,
	min_brightness = MIN_BRIGHTNESS_STEP,
	stock_brightness = STOCK_BRIGHTNESS_STEP,
	max_brightness = MAX_BRIGHTNESS_STEP,
})
local SOUL_PAYLOAD_DIR = baked.payload_dir
local GLOW_SLOTS = baked.glow_slots
local GLOW_SOURCE_EFFECTS = baked.glow_source_effects

local asset_redirect = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/asset_redirect")
local _material_format = { expected = 62, probe = "../bundle/data/e9/e90383bc561fd9ae" }

do
	local lua = rawget(_G, "Mods") and Mods.lua
	local lua_io = lua and lua.io
	local file = lua_io and lua_io.open(_material_format.probe, "rb")
	local head = file and file:read(4)

	if file then
		file:close()
	end

	if head and #head == 4 then
		local b1, b2, b3, b4 = string.byte(head, 1, 4)

		_material_format.found = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	end

	_material_format.ok = _material_format.found == _material_format.expected

	if not _material_format.ok then
		if asset_redirect then
			asset_redirect.clear(mod)
		end

		asset_redirect = nil
	end
end
local REDIRECT_CONTRACT = "polychromatic_jet/live_hsv"
local _redirect_handles = {}

if asset_redirect then
	for i = 1, #REDIRECTS do
		local entry = REDIRECTS[i]

		_redirect_handles[i] = asset_redirect.register(mod, {
			stock = entry.stock,
			file = "payload/" .. entry.file,
			sha256 = entry.sha256,
			virtual = entry.virtual,
			priority = 0,
			contract = REDIRECT_CONTRACT,
		})
	end

	asset_redirect.commit()
end

local _debug_logging = mod:get("debug_logging") == true
local VARIABLE = "lighting_far_range"
local STOCK_VALUE = 1000
local HUE_STEPS = 1024
local SATURATION_STEPS = 15
local STEPS = {
	code_divisor = 16384,
	pending_tint_frames = 30,
	burn_saturation = 4096,
	soul_swap_delay_frames = 2,
	soul_attach_frames = 2,
}
local MAX_CLOUDS = 16
local DIRECT_CLOUD = "beam"
local DIRECT_EFFECTS = mod:io_dofile(EFFECT_DATA .. "direct_effects")
local CLOUDS = {}

for i = 1, MAX_CLOUDS do
	CLOUDS[i] = "polychromatic_jet_" .. i
end

local SETS = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/sets")

local RAINBOW_CYCLES_PER_SECOND = 0.25
local _profiles = {}
local _soulblaze_enabled = true
local _flamer_burn_enabled = true
local _skull_burn_enabled = true
local _burn_patch_served = false

for i = 1, #SETS do
	local set = SETS[i]
	local by_category = {}

	for j = 1, #set.categories do
		by_category[set.categories[j]] = { set = set.id, category = set.categories[j], show = true, mode = "stock", hue = 0, saturation = 1, brightness = STOCK_BRIGHTNESS_STEP }
	end

	_profiles[set.id] = by_category
end

local function rgb_to_hsv(r, g, b)
	local max = math_max(r, g, b)
	local min = math_min(r, g, b)
	local delta = max - min
	local hue = 0

	if delta > 0 then
		if max == r then
			hue = ((g - b) / delta) % 6
		elseif max == g then
			hue = (b - r) / delta + 2
		else
			hue = (r - g) / delta + 4
		end

		hue = hue / 6
	end

	local saturation = max > 0 and delta / max or 0

	return hue, saturation, max
end

local function cache_settings()
	_debug_logging = mod:get("debug_logging") == true
	_soulblaze_enabled = mod:get("soulblaze") ~= false
	_flamer_burn_enabled = mod:get("flamer_burn") ~= false
	_skull_burn_enabled = mod:get("skull_burn") ~= false

	for set_id, by_category in pairs(_profiles) do
		for category, profile in pairs(by_category) do
			local prefix = set_id .. "_" .. category .. "_"

			profile.show = mod:get(prefix .. "show") ~= false
			profile.mode = profile.show and mod:get(prefix .. "mode") or "stock"
			profile.brightness = mod:get(prefix .. "brightness") or STOCK_BRIGHTNESS_STEP

			local colour = mod:get(prefix .. "colour")

			if type(colour) == "table" then
				profile.hue, profile.saturation = rgb_to_hsv((colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255)
			end
		end
	end
end

local function profile_for(set_id, category)
	local by_category = _profiles[set_id]

	return by_category and by_category[category]
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

local _gameplay_running = false

local _cloud_cache = {}

local function tint(world, particle_id, value)
	if not _gameplay_running then
		return false
	end

	if not World_are_particles_playing(world, particle_id) then
		return true
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

	local found = {}

	for i = 1, MAX_CLOUDS do
		local cloud = CLOUDS[i]

		if World_has_particles_material(world, particle_id, cloud) then
			World_set_particles_material_scalar(world, particle_id, cloud, VARIABLE, value)

			found[#found + 1] = cloud
		end
	end

	_cloud_cache[particle_id] = found[1] and found or nil

	return found[1] ~= nil
end

local function gameplay_time()
	local time_manager = Managers.time

	return time_manager:has_timer("gameplay") and time_manager:time("gameplay") or 0
end

local function local_player_unit()
	local player = Managers.player:local_player_safe(1)

	return player and player.player_unit
end

local SKULL_BREED_PATTERN = "servo_skull"

local function local_companions()
	local player_unit = local_player_unit()
	local spawner = player_unit and ScriptUnit.has_extension(player_unit, "companion_spawner_system")

	return spawner and spawner:companion_units()
end

local function skull_is_mine(skull_unit)
	local units = local_companions()

	if not units then
		return false
	end

	for i = 1, #units do
		if units[i] == skull_unit then
			return true
		end
	end

	return false
end

local function is_servo_skull(unit)
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data.breed and unit_data:breed()
	local breed_name = breed and breed.name

	return breed_name ~= nil and string.find(breed_name, SKULL_BREED_PATTERN, 1, true) ~= nil
end

local function category_of_unit(unit)
	if not unit then
		return "enemy"
	end

	if unit == local_player_unit() then
		return "mine"
	end

	local player_unit_spawn = Managers.state.player_unit_spawn
	local owner = player_unit_spawn and player_unit_spawn:owner(unit)

	if owner then
		return owner == Managers.player:local_player_safe(1) and "mine" or "team"
	end

	if is_servo_skull(unit) then
		return skull_is_mine(unit) and "mine" or "team"
	end

	return "enemy"
end

local function player_category(unit)
	local category = category_of_unit(unit)

	return category == "enemy" and "team" or category
end

local function hsv_to_rgb(h, s, v)
	local i = math_floor(h * 6) % 6
	local f = h * 6 - math_floor(h * 6)
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local w = v * (1 - (1 - f) * s)

	if i == 0 then
		return v, w, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, w
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return w, p, v
	end

	return v, p, q
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
	if not _gameplay_running then
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

local SPAWN_VECTOR_CLOUDS = mod:io_dofile(EFFECT_DATA .. "spawn_vector_clouds")

local function tint_mixed(world, particle_id, profile, vector_clouds)
	if not _gameplay_running then
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
	local vector_clouds = effect_name and SPAWN_VECTOR_CLOUDS[effect_name]

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

local FLASH_EFFECTS = mod:io_dofile(EFFECT_DATA .. "flash_effects")

local function apply_flash(world, particle_id, flash, profile)
	if not _gameplay_running then
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
local _effect_stats = rawget(_G, "__polychromatic_effect_stats") or {}

rawset(_G, "__polychromatic_effect_stats", _effect_stats)

local function effect_stat(effect_name, set_id, category)
	local stat = _effect_stats[effect_name]

	if not stat then
		stat = { set = set_id, category = category, seen = 0, applied = 0, deferred = 0, late = 0, expired = 0, substituted = 0 }
		_effect_stats[effect_name] = stat
	end

	stat.set = set_id or stat.set
	stat.category = category or stat.category

	return stat
end

local function apply_or_defer(stat, world, particle_id, apply, first, second, third)
	stat.seen = stat.seen + 1

	if apply(world, particle_id, first, second, third) then
		stat.applied = stat.applied + 1

		return
	end

	stat.deferred = stat.deferred + 1

	_pending_tints[#_pending_tints + 1] = {
		stat = stat,
		world = world,
		particle_id = particle_id,
		apply = apply,
		first = first,
		second = second,
		third = third,
		frames = 0,
	}
end

local function retry_pending_tints()
	if not _gameplay_running then
		return
	end

	for i = #_pending_tints, 1, -1 do
		local entry = _pending_tints[i]

		entry.frames = entry.frames + 1

		if entry.apply(entry.world, entry.particle_id, entry.first, entry.second, entry.third) then
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
end

local STAFF_IMPACT_EFFECT = "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay"
local FLAMER_IMPACT_EFFECT = "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay"

local ENCODED_EFFECTS = mod:io_dofile(EFFECT_DATA .. "encoded_effects")

local _spawn_context = {}
local _spawn_context_active = false
local _spawn_owner = nil

local function redshift_owns_sniper()
	local redshift = get_mod("Redshift")

	return redshift ~= nil and redshift:is_enabled()
end

local SNIPER_GROUP_ID = "sniper_group"
local _sniper_group_title = mod:localize(SNIPER_GROUP_ID)

local function strip_markup(text)
	if type(text) ~= "string" then
		return nil
	end

	return (text:gsub("{#.-}", ""))
end

local function set_group_data_title(widgets, title)
	for i = 1, #widgets do
		local data = widgets[i]

		if type(data) == "table" then
			if type(data.options) == "table" then
				for j = 1, #data.options do
					local option = data.options[j]

					if type(option) == "table" and option.value == SNIPER_GROUP_ID then
						option.text = title
						option.display_name = title
					end
				end
			end

			if data.setting_id == SNIPER_GROUP_ID then
				data.title = title
				data.display_name = title

				return true
			end

			if type(data.sub_widgets) == "table" and set_group_data_title(data.sub_widgets, title) then
				return true
			end
		end
	end

	return false
end

local function set_open_view_title(old_title, title)
	local ui_manager = Managers.ui
	local view = ui_manager and ui_manager:view_instance("dmf_options_view")
	local categories = view and view._settings_category_widgets

	if not categories then
		return
	end

	local old_clean = strip_markup(old_title)

	for _, widgets in pairs(categories) do
		for i = 1, #widgets do
			local widget = widgets[i] and widgets[i].widget
			local content = widget and widget.content

			if content and strip_markup(content.text) == old_clean then
				if content.entry then
					content.entry.display_name = title
					content.entry.title = title
				end

				content.text = title
				widget.dirty = true

				return
			end
		end
	end
end

local function refresh_sniper_group_title()
	local title = mod:localize(redshift_owns_sniper() and "sniper_group_redshift" or "sniper_group_plain")

	if title == _sniper_group_title then
		return
	end

	local old_title = _sniper_group_title
	local dmf = get_mod("DMF")
	local all_widgets = dmf and dmf.options_widgets_data

	_sniper_group_title = title

	if type(all_widgets) == "table" then
		local name = mod:get_name()

		for i = 1, #all_widgets do
			local mod_widgets = all_widgets[i]

			if type(mod_widgets) == "table" and mod_widgets[1] and mod_widgets[1].mod_name == name then
				set_group_data_title(mod_widgets, title)

				break
			end
		end
	end

	set_open_view_title(old_title, title)
end

mod:hook_safe(get_mod("DMF"), "set_mod_state", function(target_mod)
	if target_mod and target_mod.get_name and target_mod:get_name() == "Redshift" then
		refresh_sniper_group_title()
	end
end)

local _glow_load_ids = rawget(_G, "__polychromatic_glow_packages") or {}
local _glow_slots_loaded = false

rawset(_G, "__polychromatic_glow_packages", _glow_load_ids)

local EXTENDED_PACKAGES = mod:io_dofile(EFFECT_DATA .. "extended_packages")
local _extended_load_ids = rawget(_G, "__polychromatic_extended_packages") or {}

rawset(_G, "__polychromatic_extended_packages", _extended_load_ids)

local function pin_extended_packages()
	if not Managers.package or not asset_redirect then
		return
	end

	for i = 1, #EXTENDED_PACKAGES do
		local entry = EXTENDED_PACKAGES[i]

		if not _extended_load_ids[entry.package] then
			for k = 1, #REDIRECTS do
				if REDIRECTS[k].stock == entry.bundle and redirect_served(asset_redirect.state(_redirect_handles[k])) then
					_extended_load_ids[entry.package] = Managers.package:load(entry.package, "Polychromatic", nil, true)
				end
			end
		end
	end
end

local function load_glow_slots()
	if not Managers.package then
		return
	end

	for _, list in pairs(GLOW_SLOTS) do
		for i = 1, #list do
			local slot = list[i]

			if slot.usable and not _glow_load_ids[slot.package] then
				_glow_load_ids[slot.package] = Managers.package:load(slot.package, "Polychromatic", nil, true)
			end
		end
	end
end

local function glow_slots_ready()
	if _glow_slots_loaded then
		return true
	end

	for _, list in pairs(GLOW_SLOTS) do
		for i = 1, #list do
			local slot = list[i]

			if slot.usable then
				local id = _glow_load_ids[slot.package]

				if not id or not Managers.package:has_loaded_id(id) then
					return false
				end
			end
		end
	end

	_glow_slots_loaded = true

	return true
end

local GLOW_PARTICLE_PALETTES = mod:io_dofile(EFFECT_DATA .. "glow_particle_palettes")
local _palette_ready = {}

local function palette_ready(entry)
	if _palette_ready[entry] then
		return true
	end

	_palette_ready[entry] = Application.can_get_resource("particles", entry.names[1]) == true

	return _palette_ready[entry]
end

local BURN_PALETTES = mod:io_dofile(EFFECT_DATA .. "burn_palettes")
local _burn_palette_ready = {}

local function burn_palette_name(effect_name)
	local palette = BURN_PALETTES[effect_name]
	local profile = palette and _spawn_context_active and _spawn_context[effect_name]

	if not profile or profile.mode == "stock" or profile.mode == "hidden" then
		return nil
	end

	if not _burn_palette_ready[palette] then
		_burn_palette_ready[palette] = Application.can_get_resource("particles", palette[1]) == true

		if not _burn_palette_ready[palette] then
			return nil
		end
	end

	local hue = profile.hue or 0

	if profile.mode == "rainbow" then
		local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
	end

	return palette[math_floor(hue * #palette + 0.5) % #palette + 1]
end

local function glow_slot_for(effect_name)
	local layer = GLOW_SOURCE_EFFECTS[effect_name]
	local palette = GLOW_PARTICLE_PALETTES[effect_name]
	local owner = _spawn_owner

	if layer then
		if owner ~= "mine" or not glow_slots_ready() then
			return nil
		end
	elseif not palette or not palette_ready(palette) then
		return nil
	elseif owner ~= "mine" and owner ~= "team" then
		return nil
	end

	local set_id = palette and palette.set or "las"
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
	local slot = list[math_floor(hue * #list + 0.5) % #list + 1]

	return slot.usable and slot.package or nil
end
local SKULL_NEAR_SQUARED = 9

local function ownerless_skull_category(position)
	local units = local_companions()

	if units and position then
		for i = 1, #units do
			local unit = units[i]

			if Unit.alive(unit) and Vector3.distance_squared(Unit.world_position(unit, 1), position) < SKULL_NEAR_SQUARED then
				return "mine"
			end
		end
	end

	return "team"
end

local UNREACHABLE_EFFECTS = mod:io_dofile(EFFECT_DATA .. "unreachable_effects")

mod:hook(World, "create_particles", function(func, world, effect_name, ...)
	local spawn_name = glow_slot_for(effect_name) or burn_palette_name(effect_name) or effect_name
	local particle_id = func(world, spawn_name, ...)

	if spawn_name ~= effect_name then
		local stat = effect_stat(effect_name)

		stat.substituted = stat.substituted + 1
	end

	if not particle_id then
		return particle_id
	end

	if UNREACHABLE_EFFECTS[effect_name] or BURN_PALETTES[effect_name] then
		return particle_id
	end

	local profile = _spawn_context_active and _spawn_context[effect_name]

	if profile then
		apply_or_defer(effect_stat(effect_name, profile.set, profile.category), world, particle_id, apply_spawn, profile, nil, effect_name)

		return particle_id
	end

	local flash = FLASH_EFFECTS[effect_name]

	if flash then
		if not redshift_owns_sniper() then
			profile = profile_for("sniper", "enemy")

			if profile then
				apply_or_defer(effect_stat(effect_name, "sniper", "enemy"), world, particle_id, apply_flash, flash, profile)
			end
		end

		return particle_id
	end

	local variable = DIRECT_EFFECTS[effect_name]
	local set_id = variable and "las" or ENCODED_EFFECTS[effect_name]

	if not set_id then
		return particle_id
	end

	if set_id == "sniper" and redshift_owns_sniper() then
		return particle_id
	end

	local owner = _spawn_owner

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

local function clear_spawn_context()
	_spawn_context_active = false

	for effect_name in pairs(_spawn_context) do
		_spawn_context[effect_name] = nil
	end
end

local function call_with_spawn_context(func, ...)
	local ok, result = pcall(func, ...)

	clear_spawn_context()

	if not ok then
		error(result, 0)
	end

	return result
end

local function call_with_owner(owner, func, ...)
	local previous = _spawn_owner

	_spawn_owner = owner

	local ok, result = pcall(func, ...)

	_spawn_owner = previous

	if not ok then
		error(result, 0)
	end

	return result
end

mod:hook(CLASS.PlayerUnitFxExtension, "_create_particles_wrapper", function(func, self, ...)
	return call_with_owner(player_category(self._unit), func, self, ...)
end)

mod:hook(CLASS.PlayerUnitFxExtension, "_add_moving_vfx", function(func, self, ...)
	return call_with_owner(player_category(self._unit), func, self, ...)
end)

mod:hook(CLASS.FxSystem, "play_impact_fx", function(func, self, impact_fx, hit_position, attack_direction, source_parameters, attacking_unit, ...)
	return call_with_owner(category_of_unit(attacking_unit), func, self, impact_fx, hit_position, attack_direction, source_parameters, attacking_unit, ...)
end)

mod:hook(CLASS.FxSystem, "play_surface_impact_fx", function(func, self, hit_position, hit_direction, source_parameters, attacking_unit, ...)
	return call_with_owner(category_of_unit(attacking_unit), func, self, hit_position, hit_direction, source_parameters, attacking_unit, ...)
end)

mod:hook(CLASS.FxSystem, "play_shotshell_surface_impact_fx", function(func, self, fire_position, hit_positions, hit_normals, source_parameters, attacking_unit, ...)
	return call_with_owner(category_of_unit(attacking_unit), func, self, fire_position, hit_positions, hit_normals, source_parameters, attacking_unit, ...)
end)

mod:hook(CLASS.MinionFxExtension, "_trigger_inventory_vfx", function(func, self, ...)
	return call_with_owner(category_of_unit(self._unit), func, self, ...)
end)

mod:hook(CLASS.MinionFxExtension, "_trigger_unit_line_fx", function(func, self, ...)
	return call_with_owner(category_of_unit(self._unit), func, self, ...)
end)

local SLOT_SCRIPT_SPAWNERS = {
	ForceWeaponBlockEffects = { "update" },
	ForceWeaponWindSlashStageEffects = { "update", "wield" },
	ForceWeaponWindSlashActivationEffects = { "update_unit_position" },
	PlasmagunOverheatEffects = { "update" },
}
local _slot_script_owners = setmetatable({}, { __mode = "k" })

local function slot_script_category(slot_script)
	local category = _slot_script_owners[slot_script]

	if type(category) ~= "string" then
		category = player_category(category or slot_script._owner_unit)
		_slot_script_owners[slot_script] = category
	end

	return category
end

for class_name, methods in pairs(SLOT_SCRIPT_SPAWNERS) do
	mod:hook_safe(CLASS[class_name], "init", function(self, context)
		_slot_script_owners[self] = context and context.owner_unit
	end)

	for i = 1, #methods do
		mod:hook(CLASS[class_name], methods[i], function(func, self, ...)
			return call_with_owner(slot_script_category(self), func, self, ...)
		end)
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

	_spawn_context[flamer_set(self) == "staff" and STAFF_IMPACT_EFFECT or FLAMER_IMPACT_EFFECT] = profile
	_spawn_context_active = true

	return call_with_spawn_context(func, self, dt, t)
end)

local _hidden_streams = setmetatable({}, { __mode = "k" })

local function hide_stream(owner, world, stream_effect_id)
	if _hidden_streams[owner] ~= stream_effect_id then
		World_stop_spawning_particles(world, stream_effect_id)

		_hidden_streams[owner] = stream_effect_id
	end
end

mod:hook_safe(CLASS.FlamerGasEffects, "_update_effects", function(self, dt, t)
	local stream_effect_id = self._stream_effect_id

	if not stream_effect_id then
		_hidden_streams[self] = nil
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

local BURN_IDS = {
	soulblaze_buff = "warp_fire",
	ailment_templates = require("scripts/settings/ailments/ailment_settings").effect_templates,
	soulblaze_ailment = require("scripts/settings/ailments/ailment_settings").effects.warpfire,
	flamer_buff = "flamer_assault",
	flamer_ailment = require("scripts/settings/ailments/ailment_settings").effects.burning,
}
local BURN_TIMING_VARIABLE = "offset_time_duration"
local BURN_UNPATCHED_BREED_PATTERNS = { "daemonhost" }
local BURN_HUE_STEPS = 256
local BURN_CODE_SCALE = 4
local _burn_starts = setmetatable({}, { __mode = "k" })

mod:hook_safe(require("scripts/utilities/ailment"), "play_ailment_effect_template", function(unit, ailment_effect, optional_include_children, optional_custom_duration, optional_custom_offset_time)
	if (ailment_effect ~= BURN_IDS.soulblaze_ailment and ailment_effect ~= BURN_IDS.flamer_ailment) or not unit or not Unit.alive(unit) then
		return
	end

	local template = BURN_IDS.ailment_templates[ailment_effect]

	_burn_starts[unit] = {
		start = World.time(Unit.world(unit)),
		offset = optional_custom_offset_time or template.offset_time,
		duration = optional_custom_duration or template.duration,
	}
end)

local function burn_patched(unit)
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local breed_name = breed and breed.name

	if not breed_name then
		return false
	end

	for i = 1, #BURN_UNPATCHED_BREED_PATTERNS do
		if string.find(breed_name, BURN_UNPATCHED_BREED_PATTERNS[i], 1, true) then
			return false
		end
	end

	return true
end

local function burn_code(profile, t)
	local hue = profile.hue
	local saturation = profile.saturation

	if profile.mode == "rainbow" then
		local phase = t * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
		saturation = 1
	end

	local hue_step = math_floor(hue * BURN_HUE_STEPS) % BURN_HUE_STEPS
	local saturation_step = math_floor(saturation * SATURATION_STEPS + 0.5)
	local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, math_floor(profile.brightness + 0.5)))

	return saturation_step * STEPS.burn_saturation + hue_step * 16 + brightness_step
end

local SOULBLAZE_FLAME = "content/fx/particles/enemies/buff_warpfire"
local SOUL_PACKAGE_REFERENCE = "Polychromatic"
local _soul_load_ids = rawget(_G, "__polychromatic_soul_packages") or {}

rawset(_G, "__polychromatic_soul_packages", _soul_load_ids)
local _soul_slots_ready = false

local function load_soul_slots()
	for i = 1, #SOUL_SLOTS do
		local slot = SOUL_SLOTS[i]

		if slot.usable then
			if not _soul_load_ids[slot.package] then
				_soul_load_ids[slot.package] = Managers.package:load(slot.package, SOUL_PACKAGE_REFERENCE, nil, true)
			end
		end
	end
end

local _soul_load_warned = false

local function soul_slots_ready()
	if _soul_slots_ready then
		return true
	end

	if next(_soul_load_ids) == nil then
		if not _soul_load_warned then
			_soul_load_warned = true
			mod:info("soulblaze flames: no slot packages loaded, flames stay stock")
		end

		return false
	end

	for _, id in pairs(_soul_load_ids) do
		if not Managers.package:has_loaded_id(id) then
			return false
		end
	end

	_soul_slots_ready = true

	return true
end

local function soul_slot_for(profile, t)
	local hue = profile.hue or 0

	if profile.mode == "rainbow" then
		local phase = t * RAINBOW_CYCLES_PER_SECOND

		hue = phase - math_floor(phase)
	end

	local slot = SOUL_SLOTS[math_floor(hue * #SOUL_SLOTS + 0.5) % #SOUL_SLOTS + 1]

	return slot.usable and slot or nil
end

local _pending_soul_swaps = {}
local _pending_soul_attach = {}

local function swap_soulblaze_flame(extension, unit, profile, t)
	if not soul_slots_ready() then
		return
	end

	local slot = soul_slot_for(profile, t)

	if slot then
		_pending_soul_swaps[#_pending_soul_swaps + 1] = { extension = extension, unit = unit, slot = slot, wait = STEPS.soul_swap_delay_frames }
	end
end

local function apply_soul_swap(entry)
	local extension, unit = entry.extension, entry.unit

	if not Unit.alive(unit) then
		return
	end

	local context = extension._buff_context
	local world = context and context.world
	local node_effects = extension._vfx_node_effects

	if not world or not node_effects then
		return
	end

	for _, per_node in pairs(node_effects) do
		local data = per_node[SOULBLAZE_FLAME]

		if data and data.particle_id then
			World.destroy_particles(world, data.particle_id)

			local particle_id = World.create_particles(world, entry.slot.package, Unit.world_position(unit, 1))

			World.set_particles_surface_effect(world, particle_id, unit, nil, nil, true)

			data.particle_id = particle_id
			_pending_soul_attach[#_pending_soul_attach + 1] = { world = world, unit = unit, particle_id = particle_id, wait = STEPS.soul_attach_frames }
		end
	end
end

local function run_pending_soul_attach()
	local waiting = {}

	for i = 1, #_pending_soul_attach do
		local entry = _pending_soul_attach[i]

		entry.wait = entry.wait - 1

		if entry.wait > 0 then
			waiting[#waiting + 1] = entry
		elseif Unit.alive(entry.unit) and World.are_particles_playing(entry.world, entry.particle_id) then
			World.set_particles_surface_effect(entry.world, entry.particle_id, entry.unit, nil, nil, true)
		end
	end

	_pending_soul_attach = waiting
end

local function run_pending_soul_swaps()
	local waiting = {}

	for i = 1, #_pending_soul_swaps do
		local entry = _pending_soul_swaps[i]

		entry.wait = entry.wait - 1

		if entry.wait > 0 then
			waiting[#waiting + 1] = entry
		else
			apply_soul_swap(entry)
		end
	end

	_pending_soul_swaps = waiting
end

local function clear_pending_soul_swaps()
	_pending_soul_swaps = {}
	_pending_soul_attach = {}
end

local SKULL_ARCHETYPE = "cryptic"

local function burn_set_for(owner_unit)
	if not owner_unit then
		return nil
	end

	local spawn_manager = Managers.state.player_unit_spawn
	local player = spawn_manager and spawn_manager:owner(owner_unit)

	if player then
		if player:archetype_name() == SKULL_ARCHETYPE then
			return _skull_burn_enabled and "skull" or nil
		end

		return _flamer_burn_enabled and "flamer" or nil
	end

	if is_servo_skull(owner_unit) then
		return _skull_burn_enabled and "skull" or nil
	end

	return _flamer_burn_enabled and "flamer" or nil
end

local function flamer_burn_profile_for(template_name, owner_unit)
	if template_name ~= BURN_IDS.flamer_buff then
		return nil
	end

	local set_id = burn_set_for(owner_unit)
	local category = category_of_unit(owner_unit)

	if set_id == "skull" and category ~= "mine" then
		local spawn_manager = Managers.state.player_unit_spawn
		local player = spawn_manager and spawn_manager:owner(owner_unit)
		local local_player = Managers.player:local_player_safe(1)

		category = ((player and player == local_player) or skull_is_mine(owner_unit)) and "mine" or "team"
	end

	local profile = set_id and profile_for(set_id, category)

	if not profile or not profile.show or profile.mode == "stock" or profile.mode == "hidden" then
		return nil
	end

	return profile
end

local function flamer_burn_profile(buff_instance)
	return flamer_burn_profile_for(buff_instance:template().name, buff_instance:owner_unit())
end

local function flamer_burn_added(self, buff_instance)
	local profile = flamer_burn_profile(buff_instance)
	local unit = self._unit

	if not profile or not unit then
		return
	end

	local timing = _burn_starts[unit]

	_burn_starts[unit] = nil

	if not Unit.alive(unit) then
		return
	end

	local t = gameplay_time()

	if not timing or not _burn_patch_served or not burn_patched(unit) then
		return
	end

	local code = burn_code(profile, t)

	Unit.set_vector3_for_materials(unit, BURN_TIMING_VARIABLE, Vector3(BURN_CODE_SCALE * code + timing.offset, timing.start, timing.duration), true)
end

local function call_with_burn_context(profile, func, ...)
	if not profile then
		return func(...)
	end

	for effect_name in pairs(BURN_PALETTES) do
		_spawn_context[effect_name] = profile
	end

	_spawn_context_active = true

	return call_with_spawn_context(func, ...)
end

local function burn_owner_from_args(...)
	for i = 1, select("#", ...), 2 do
		if select(i, ...) == "owner_unit" then
			return (select(i + 1, ...))
		end
	end

	return nil
end

mod:hook(CLASS.MinionBuffExtension, "_add_buff", function(func, self, template, t, from_server_correction, ...)
	local profile = flamer_burn_profile_for(template and template.name, burn_owner_from_args(...))

	return call_with_burn_context(profile, func, self, template, t, from_server_correction, ...)
end)

mod:hook(CLASS.MinionBuffExtension, "_on_add_buff", function(func, self, buff_instance)
	func(self, buff_instance)
	flamer_burn_added(self, buff_instance)

	if not _soulblaze_enabled or buff_instance:template().name ~= BURN_IDS.soulblaze_buff then
		return
	end

	local unit = self._unit

	if not unit then
		return
	end

	local timing = _burn_starts[unit]

	_burn_starts[unit] = nil

	if not Unit.alive(unit) then
		return
	end

	local profile = profile_for("staff", category_of_unit(buff_instance:owner_unit()))

	if not profile or not profile.show or profile.mode == "stock" then
		return
	end

	local t = gameplay_time()

	swap_soulblaze_flame(self, unit, profile, t)

	if not timing or not _burn_patch_served or not burn_patched(unit) then
		return
	end

	local code = burn_code(profile, t)

	Unit.set_vector3_for_materials(unit, BURN_TIMING_VARIABLE, Vector3(BURN_CODE_SCALE * code + timing.offset, timing.start, timing.duration), true)
end)

local servo_skull_flamer = require("scripts/settings/fx/effect_templates/companion_servo_skull_flamer")

mod:hook_safe(servo_skull_flamer, "update", function(template_data, template_context, dt, t)
	local stream_effect_id = template_data.stream_effect_id

	if not stream_effect_id then
		_hidden_streams[template_data] = nil

		return
	end

	local profile = profile_for("skull", skull_is_mine(template_data.unit) and "mine" or "team")

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
end)

mod.update = function()
	if _pending_tints[1] then
		retry_pending_tints()
	end

	if _pending_soul_swaps[1] then
		run_pending_soul_swaps()
	end

	if _pending_soul_attach[1] then
		run_pending_soul_attach()
	end
end

mod.on_game_state_changed = function(status, state_name)
	local gameplay_init = state_name == "GameplayStateRun"
		or string.sub(state_name or "", 1, 12) == "GameplayInit"

	if status == "enter" then
		_gameplay_running = state_name == "GameplayStateRun"
	elseif state_name == "StateGameplay" or state_name == "GameplayStateRun" then
		_gameplay_running = false
	end

	if not gameplay_init then
		clear_pending_tints()
		clear_pending_soul_swaps()
	end

	if state_name == "StateGameplay" and status == "enter" then
		load_soul_slots()
		load_glow_slots()
		pin_extended_packages()
	end
end

mod.on_setting_changed = function()
	cache_settings()
end

mod.on_settings_reset = function()
	cache_settings()
end

cache_settings()

mod.on_all_mods_loaded = function()
	mod:info("Polychromatic %s loaded", tostring(mod.version))

	local ui = Managers.ui
	local in_level = ui ~= nil and ui:get_current_sub_state_name() == "GameplayStateRun"

	_gameplay_running = in_level

	if not _material_format.ok then
		mod:info("game material format %s, payload built for %s: every patched file stays stock", tostring(_material_format.found), tostring(_material_format.expected))
		mod:echo(mod:localize("game_format_changed"))
	end

	if not asset_redirect then
		return
	end

	asset_redirect.commit()

	local served = 0
	local restart = false

	for i = 1, #_redirect_handles do
		local state = asset_redirect.state(_redirect_handles[i])

		if redirect_served(state) then
			served = served + 1
		else
			if _debug_logging then
				mod:info("redirect %s: %s", REDIRECTS[i].stock, state)
			end
		end

		restart = restart or state == "restart_required"
	end

	if _debug_logging then
		mod:info("redirects served: %d of %d", served, #_redirect_handles)
	end

	local burn_entries, burn_served = 0, 0

	for i = 1, #REDIRECTS do
		if string.find(REDIRECTS[i].file, "%.burnhsv$") then
			local state = asset_redirect.state(_redirect_handles[i])

			burn_entries = burn_entries + 1

			if redirect_served(state) then
				burn_served = burn_served + 1
			end
		end
	end

	_burn_patch_served = burn_entries > 0 and burn_served == burn_entries

	if _debug_logging then
		mod:info("burn shader patch served: %s", tostring(_burn_patch_served))
	end

	local soul_usable = 0

	for i = 1, #SOUL_SLOTS do
		local slot = SOUL_SLOTS[i]

		slot.usable = redirect_served(asset_redirect.state(_redirect_handles[slot.bundle_redirect])) and redirect_served(asset_redirect.state(_redirect_handles[slot.material_redirect]))

		if slot.usable then
			soul_usable = soul_usable + 1
		end
	end

	if _debug_logging then
		mod:info("soulblaze flame slots usable: %d of %d", soul_usable, #SOUL_SLOTS)
	end

	local glow_usable, glow_total = 0, 0

	for _, list in pairs(GLOW_SLOTS) do
		for i = 1, #list do
			local slot = list[i]
			local bundle_ok, material_ok = false, false

			for k = 1, #REDIRECTS do
				if REDIRECTS[k].stock == slot.bundle then
					bundle_ok = redirect_served(asset_redirect.state(_redirect_handles[k]))
				elseif REDIRECTS[k].stock == slot.virtual_path then
					material_ok = redirect_served(asset_redirect.state(_redirect_handles[k]))
				end
			end

			slot.usable = bundle_ok and material_ok
			glow_total = glow_total + 1

			if slot.usable then
				glow_usable = glow_usable + 1
			end
		end
	end

	if _debug_logging then
		mod:info("las glow slots usable: %d of %d", glow_usable, glow_total)
	end

	if in_level then
		load_soul_slots()
		load_glow_slots()
		pin_extended_packages()
	end

	if restart then
		mod:echo(mod:localize("restart_required"))
	end
end

local diagnostics = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/Polychromatic_debug")({
	mod = mod,
	redirects = REDIRECTS,
	payload_dir = SOUL_PAYLOAD_DIR,
	soul_slots = SOUL_SLOTS,
	glow_slots = GLOW_SLOTS,
	extended_packages = EXTENDED_PACKAGES,
	sets = SETS,
	asset_redirect = asset_redirect,
	redirect_handles = _redirect_handles,
	redirect_served = redirect_served,
	profile_for = profile_for,
	redshift_owns_sniper = redshift_owns_sniper,
	effect_stats = _effect_stats,
	soul_load_ids = _soul_load_ids,
	glow_load_ids = _glow_load_ids,
	extended_load_ids = _extended_load_ids,
	flags = function()
		return {
			gameplay_running = _gameplay_running,
			burn_patch_served = _burn_patch_served,
			soulblaze = _soulblaze_enabled,
			flamer_burn = _flamer_burn_enabled,
			skull_burn = _skull_burn_enabled,
			debug_logging = _debug_logging,
		}
	end,
})

mod:hook_safe(CLASS.PackageManager, "load", function(self, package_name, reference_name, callback, prioritize, use_resident_loading)
	if _debug_logging then
		diagnostics.package_loaded(package_name, reference_name, prioritize, use_resident_loading)
	end
end)

mod:command("poly_check", mod:localize("poly_check_description"), function()
	diagnostics.check_setup(false)
end)

local report_load = mod.on_all_mods_loaded

mod.on_all_mods_loaded = function()
	report_load()

	if _debug_logging then
		diagnostics.check_setup(true, true)
	end
end

local apply_setting = mod.on_setting_changed

mod.on_setting_changed = function(setting_id)
	local was_logging = _debug_logging

	apply_setting(setting_id)

	if setting_id == "debug_logging" and _debug_logging and not was_logging then
		diagnostics.check_setup(true, true)
	end
end
