--[[
	Name: Polychromatic
	Author: Wobin
	Date: 24/10/2026
]]--

local mod = get_mod("Polychromatic")
local STARTUP = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/startup_timer")
local file_timer = STARTUP.start()
local startup_detail = STARTUP.detail()
mod.version = mod.get_metadata and mod:get_metadata("version") or "unknown"

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local get_mod = get_mod
local MODULE_LIST = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/module_list")
local REGISTRY = MODULE_LIST.registry(mod)
local MOD_FOLDER = MODULE_LIST.folder(mod)

file_timer.lap("registry")
startup_detail.mark()

local function module_data_file(manifest, kind)
	local file = manifest.data and manifest.data[kind]

	return file and mod:io_dofile("Polychromatic/modules/" .. manifest.id .. "/data/" .. file)
end

local function module_data(kind)
	local merged = {}

	for _, manifest in ipairs(REGISTRY.modules) do
		local part = module_data_file(manifest, kind)

		if type(part) == "table" and #part > 0 then
			for i = 1, #part do
				merged[#merged + 1] = part[i]
			end
		elseif type(part) == "table" then
			for key, value in pairs(part) do
				if merged[key] == nil then
					merged[key] = value
				end
			end
		end
	end

	return merged
end

local function module_redirect_groups(kinds)
	local groups = {}

	for _, manifest in ipairs(REGISTRY.modules) do
		for _, kind in ipairs(kinds) do
			local list = module_data_file(manifest, kind)

			if type(list) == "table" then
				groups[#groups + 1] = { module = manifest.id, list = list }
			end
		end
	end

	return groups
end

local function has_source(id)
	for _, source in ipairs(REGISTRY.sources) do
		if source.id == id then
			return true
		end
	end

	return false
end

local function data_module(kind)
	for _, manifest in ipairs(REGISTRY.modules) do
		if manifest.data and manifest.data[kind] then
			return manifest.id
		end
	end

	return nil
end

local PAYLOAD_STAT = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/file_stat").stat
local MODULES_ROOT = "../mods/" .. MOD_FOLDER .. "/modules/"

local function payload_identity(entry, module_id)
	if not PAYLOAD_STAT or type(module_id) ~= "string" then
		return nil
	end

	return (PAYLOAD_STAT(MODULES_ROOT .. module_id .. "/payload/" .. entry.file))
end

local function merge_redirect_groups(groups, into)
	local merged, conflicts = REGISTRY.merge_redirects(groups, payload_identity, into)

	for _, conflict in ipairs(conflicts) do
		mod:info("redirect conflict: %s from %s (%s)", conflict.stock, tostring(conflict.module), conflict.reason)
	end

	return merged
end

local REDIRECTS = merge_redirect_groups(module_redirect_groups({ "redirects", "las_redirects", "burn_redirects", "glow_redirects" }))

startup_detail.lap("other", "merge")

local MIN_BRIGHTNESS_STEP = 1
local STOCK_BRIGHTNESS_STEP = 8
local MAX_BRIGHTNESS_STEP = 15

local function redirect_served(state)
	return state == "active" or state == "shared" or state == "compatible"
end

local BAKE_KINDS = {
	soul = { "soul_slots" },
	burn = { "burn_palettes" },
	skull_burn = { "skull_burn_palettes" },
	glow = { "glow_redirects", "glow_slots" },
	plasma = { "plasma_trail_slots" },
}

local function bake_module(part)
	for name, kinds in pairs(BAKE_KINDS) do
		if part == nil or part == name then
			for _, kind in ipairs(kinds) do
				local id = data_module(kind)

				if id then
					return id
				end
			end
		end
	end

	return nil
end

file_timer.mark()
startup_detail.mark()

local SOUL_SLOTS = module_data("soul_slots")
local baked = bake_module() and mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/Polychromatic_bake")({
	mod = mod,
	data = module_data,
	bake_module = bake_module,
	detail = startup_detail,
	redirects = REDIRECTS,
	merge = function(groups)
		merge_redirect_groups(groups, REDIRECTS)
	end,
	has_source = has_source,
	soul_slots = SOUL_SLOTS,
	min_brightness = MIN_BRIGHTNESS_STEP,
	stock_brightness = STOCK_BRIGHTNESS_STEP,
	max_brightness = MAX_BRIGHTNESS_STEP,
}) or { glow_slots = {}, glow_source_effects = {} }
local GLOW_SLOTS = baked.glow_slots

file_timer.lap("bake")
startup_detail.mark()

local REDIRECT_LIBRARY = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/asset_redirect") or nil
local asset_redirect = REDIRECT_LIBRARY

local function probe_material_format(format)
	local lua = rawget(_G, "Mods") and Mods.lua
	local lua_io = lua and lua.io
	local file = lua_io and lua_io.open(format.probe, "rb")
	local head = file and file:read(4)

	if file then
		file:close()
	end

	if head and #head == 4 then
		local b1, b2, b3, b4 = string.byte(head, 1, 4)

		format.found = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	end

	format.missing = format.found == nil
	format.ok = format.found == format.expected

	return format
end

local _material_format = probe_material_format({ expected = 62, probe = "../bundle/data/e9/e90383bc561fd9ae" })

if not _material_format.ok then
	if asset_redirect then
		asset_redirect.clear(mod)
	end

	asset_redirect = nil
end

local _redirect_handles = {}

startup_detail.lap("other", "redirect lib")
file_timer.mark()

if asset_redirect then
	for i = 1, #REDIRECTS do
		local entry = REDIRECTS[i]

		_redirect_handles[i] = asset_redirect.register(mod, {
			stock = entry.stock,
			file = "modules/" .. entry.module .. "/payload/" .. entry.file,
			sha256 = entry.sha256,
			virtual = entry.virtual,
			priority = 0,
			contract = "polychromatic_jet/live_hsv",
		})
	end

	asset_redirect.commit()
end

file_timer.lap("redirects register")

local _debug_logging = mod:get("debug_logging") == true
local SATURATION_STEPS = 15
local BURN_SATURATION = 4096

local SETS = REGISTRY.sources

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

local STATE = {
	gameplay_running = false,
	spawn_context = {},
	spawn_context_active = false,
	spawn_owner = nil,
	staff_unit = nil,
	soul_spawn = nil,
}

local function with_traceback(err)
	local message = tostring(err)

	if string.find(message, "stack traceback:", 1, true) then
		return message
	end

	return debug.traceback(message, 2)
end

local function gameplay_time()
	local time_manager = Managers.time

	return time_manager:has_timer("gameplay") and time_manager:time("gameplay") or 0
end

local function local_player_unit()
	local player = Managers.player:local_player_safe(1)

	return player and player.player_unit
end


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

	return breed_name ~= nil and string.find(breed_name, "servo_skull", 1, true) ~= nil
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

local function clear_spawn_context()
	STATE.spawn_context_active = false

	for effect_name in pairs(STATE.spawn_context) do
		STATE.spawn_context[effect_name] = nil
	end
end

local function call_with_spawn_context(func, ...)
	local ok, result = xpcall(func, with_traceback, ...)

	clear_spawn_context()

	if not ok then
		error(result, 0)
	end

	return result
end

local ENGINE = {}

local function resolve_set(set_id, effect_name)
	if set_id == "psyker_blitz" then
		return ENGINE.blitz_routing and ENGINE.blitz_routing.resolve(STATE.staff_unit) or nil
	end

	local weapon_routing = ENGINE.weapon_routing

	if weapon_routing then
		local routed, handled = weapon_routing.resolve(set_id, effect_name, STATE.staff_unit)

		if handled then
			return routed
		end
	end

	if set_id ~= "force_staff" then
		return set_id
	end

	return ENGINE.staff_routing and ENGINE.staff_routing.resolve(effect_name, STATE.staff_unit) or nil
end

local function redshift_owns_sniper()
	local redshift = get_mod("Redshift")

	return redshift ~= nil and redshift:is_enabled()
end

local EFFECT_PACKAGES = nil

local RESOURCE_MODULE = {}

local function resource_ready(cache, key, type_name, name)
	return EFFECT_PACKAGES.resource_ready(cache, key, type_name, name, RESOURCE_MODULE[name])
end

startup_detail.mark()

local BURN_PALETTE_SETS = { flamer = module_data("burn_palettes"), skull = module_data("skull_burn_palettes") }
local BURN_PALETTES = {}

for _, palettes in pairs(BURN_PALETTE_SETS) do
	for effect_name in pairs(palettes) do
		BURN_PALETTES[effect_name] = true
	end
end

for _, manifest in ipairs(REGISTRY.modules) do
	for _, kind in ipairs({ "burn_palettes", "skull_burn_palettes", "glow_particle_palettes" }) do
		local part = module_data_file(manifest, kind)

		for _, list in pairs(type(part) == "table" and part or {}) do
			local names = type(list) == "table" and (type(list.names) == "table" and list.names or list) or {}

			for _, name in ipairs(names) do
				RESOURCE_MODULE[name] = RESOURCE_MODULE[name] or manifest.id
			end
		end
	end
end

startup_detail.lap("other", "burn data")

local function call_with_owner_unit(unit, owner, func, ...)
	local previous_owner, previous_unit = STATE.spawn_owner, STATE.staff_unit

	STATE.spawn_owner, STATE.staff_unit = owner, unit

	local ok, result = xpcall(func, with_traceback, ...)

	STATE.spawn_owner, STATE.staff_unit = previous_owner, previous_unit

	if not ok then
		error(result, 0)
	end

	return result
end

local function register_owner_hook(target, method, owner_of, after)
	mod:hook(target, method, function(func, self, ...)
		local unit, owner = owner_of(self, ...)
		local result = call_with_owner_unit(unit, owner, func, self, ...)

		if after then
			after(self, owner)
		end

		return result
	end)
end

file_timer.mark()
startup_detail.mark()

mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/cleanup_guard")(mod)
local function engines_in_use()
	for _, name in ipairs({ "live_tint", "weapon_glow", "unit_hues", "decal_swap" }) do
		local engine = ENGINE[name]
		local in_use = engine and engine.in_use

		if in_use then
			local ok, live = pcall(in_use)

			if not ok or live then
				return true
			end
		end
	end

	return false
end

local function drop_package_copies()
	local live_tint = ENGINE.live_tint

	if live_tint and live_tint.drop_package_particles then
		local ok, err = pcall(live_tint.drop_package_particles)

		if not ok then
			mod:info("live_tint drop failed: %s", tostring(err))
		end
	end

	for _, name in ipairs({ "weapon_glow", "unit_hues", "decal_swap" }) do
		local engine = ENGINE[name]

		if engine and engine.restore then
			local ok, err = pcall(engine.restore)

			if not ok then
				mod:info("%s restore failed: %s", name, tostring(err))
			end
		end
	end
end

local _after_boot = {}
local _booted = false

local function run_after_boot()
	_booted = true

	local queued = _after_boot

	_after_boot = {}

	for i = 1, #queued do
		local ok, err = xpcall(queued[i].fn, with_traceback)

		if not ok then
			mod:info("engine %s setup after boot failed: %s", tostring(queued[i].name), tostring(err))
		end
	end
end

local function after_boot(name, fn)
	_after_boot[#_after_boot + 1] = { name = name, fn = fn }

	if _booted then
		run_after_boot()
	end
end

EFFECT_PACKAGES = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/effect_packages")(mod, module_data, (function()
	local mods_lua = rawget(_G, "Mods") and Mods.lua

	return {
		modules = REGISTRY.modules,
		asset_redirect = asset_redirect,
		table = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/hosts"),
		ffi = mods_lua and mods_lua.ffi,
		json = rawget(_G, "cjson"),
		native = function()
			return REDIRECT_LIBRARY and REDIRECT_LIBRARY.native() or nil
		end,
		has = function(symbol)
			return REDIRECT_LIBRARY ~= nil and REDIRECT_LIBRARY.has(symbol) == true
		end,
		redirect_stocks = function()
			local set = {}

			for i = 1, #REDIRECTS do
				set[REDIRECTS[i].stock] = true
			end

			return set
		end,
		in_use = engines_in_use,
		drop_copies = drop_package_copies,
		folder = function()
			return "mods/" .. MOD_FOLDER
		end,
		package_loaded = function(name)
			local manager = Managers.package

			return manager ~= nil and manager:has_loaded(name) == true
		end,
		opens = function(host)
			local count = asset_redirect and asset_redirect.opens and asset_redirect.opens(host)

			return type(count) == "number" and count or nil
		end,
		no_world = function()
			local wm = Managers.world

			return wm == nil or not wm:has_world("level_world")
		end,
		gameplay_running = function()
			return STATE.gameplay_running == true
		end,
	}
end)())
startup_detail.lap("engines", "packages")

local ENGINE_LIB = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/engines")
local _, ENGINE_DISABLED = ENGINE_LIB.load(mod, REGISTRY, {
	detail = startup_detail,
	engines = ENGINE,
	state = STATE,
	profile_for = profile_for,
	player_category = player_category,
	category_of_unit = category_of_unit,
	is_servo_skull = is_servo_skull,
	skull_is_mine = skull_is_mine,
	resolve_set = resolve_set,
	register_owner_hook = register_owner_hook,
	call_with_spawn_context = call_with_spawn_context,
	call_with_owner_unit = call_with_owner_unit,
	effect_stat = effect_stat,
	redshift_owns_sniper = redshift_owns_sniper,
	gameplay_time = gameplay_time,
	with_traceback = with_traceback,
	after_boot = after_boot,
	resource_ready = resource_ready,
	rgb_to_hsv = rgb_to_hsv,
	hsv_to_rgb = hsv_to_rgb,
	data = module_data,
	EFFECT_PACKAGES = EFFECT_PACKAGES,
	package_generation = EFFECT_PACKAGES.generation,
	palettes = EFFECT_PACKAGES.all(),
	effect_slots = EFFECT_PACKAGES.slots,
	soul_slots = SOUL_SLOTS,
	glow_slots = GLOW_SLOTS,
	glow_source_effects = baked.glow_source_effects,
	burn_palettes = BURN_PALETTES,
	burn_palette_sets = BURN_PALETTE_SETS,
	murmur_preimage = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/murmur_preimage"),
	unit_slots = function(key)
		return EFFECT_PACKAGES.slots(key)
	end,
	flag = function(name)
		if name == "soulblaze" then
			return _soulblaze_enabled
		elseif name == "flamer_burn" then
			return _flamer_burn_enabled
		elseif name == "skull_burn" then
			return _skull_burn_enabled
		end

		return _burn_patch_served
	end,
	swap_soul_spawn = function(value)
		local previous = STATE.soul_spawn

		STATE.soul_spawn = value

		return previous
	end,
	call_with_burn_context = function(profile, func, ...)
		if not profile then
			return func(...)
		end

		for effect_name in pairs(BURN_PALETTES) do
			STATE.spawn_context[effect_name] = profile
		end

		STATE.spawn_context_active = true

		return call_with_spawn_context(func, ...)
	end,
	STOCK_BRIGHTNESS_STEP = STOCK_BRIGHTNESS_STEP,
	RAINBOW_CYCLES_PER_SECOND = RAINBOW_CYCLES_PER_SECOND,
	SATURATION_STEPS = SATURATION_STEPS,
	MIN_BRIGHTNESS_STEP = MIN_BRIGHTNESS_STEP,
	MAX_BRIGHTNESS_STEP = MAX_BRIGHTNESS_STEP,
	BURN_SATURATION = BURN_SATURATION,
})

file_timer.lap("engines")

local REDIRECT_WAIT_CAP_SECONDS = 10
local _redirects_waiting = false
local _redirects_waited = 0
local _redirects_settled = false
local _redirects_capped = false
local _restart_told = false
local _setup_after_settle = false
local diagnostics = nil

local function settle_redirects()
	local first_settle = not _redirects_settled

	_redirects_waiting = false
	_redirects_settled = true

	if asset_redirect then
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

			slot.usable = redirect_served(asset_redirect.state(_redirect_handles[slot.material_redirect]))

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
				local material_ok = false

				for k = 1, #REDIRECTS do
					if REDIRECTS[k].stock == slot.virtual_path then
						material_ok = redirect_served(asset_redirect.state(_redirect_handles[k]))
					end
				end

				slot.usable = material_ok
				glow_total = glow_total + 1

				if slot.usable then
					glow_usable = glow_usable + 1
				end
			end
		end

		if _debug_logging then
			mod:info("las glow slots usable: %d of %d", glow_usable, glow_total)
		end

		if restart and not _restart_told then
			_restart_told = true
			mod:echo("%s", mod:localize("restart_required"))
		end

		local verify_ms, verify_hashed, verify_pinned = asset_redirect.verified()

		if verify_ms then
			mod:info("redirects verified off the main thread in %.1f ms (%.0f bytes hashed, %.0f pinned)", verify_ms, verify_hashed or 0, verify_pinned or 0)
		end
	end

	if first_settle then
		EFFECT_PACKAGES.acquire()
	end

	if _setup_after_settle and not _redirects_capped then
		_setup_after_settle = false
		diagnostics.check_setup(true, true)
	end
end

mod.update = function(dt)
	EFFECT_PACKAGES.update()

	if _redirects_waiting then
		_redirects_waited = _redirects_waited + (dt or 0)

		if asset_redirect.ready() then
			settle_redirects()
		elseif _redirects_waited >= REDIRECT_WAIT_CAP_SECONDS then
			mod:info("redirect verification did not finish within %d s: using what was verified, the rest stays stock", REDIRECT_WAIT_CAP_SECONDS)
			_redirects_capped = true
			settle_redirects()
		end
	elseif _redirects_capped and asset_redirect.ready() then
		_redirects_capped = false
		settle_redirects()
	end

	if ENGINE.weapon_glow then
		ENGINE.weapon_glow.update(dt or 0)
	end

	if ENGINE.colour_channels then
		ENGINE.colour_channels.update(dt or 0)
	end

	if ENGINE.scene_lights then
		ENGINE.scene_lights.update()
	end

	if ENGINE.live_tint then
		ENGINE.live_tint.update()
	end
end

mod.on_game_state_changed = function(status, state_name)
	local gameplay_init = state_name == "GameplayStateRun"
		or string.sub(state_name or "", 1, 12) == "GameplayInit"

	if status == "enter" and state_name == "StateGameplay" and not _booted then
		run_after_boot()
	end

	if status == "enter" then
		STATE.gameplay_running = state_name == "GameplayStateRun"
	elseif state_name == "StateGameplay" or state_name == "GameplayStateRun" then
		STATE.gameplay_running = false
	end

	if not gameplay_init then
		if ENGINE.live_tint then
			ENGINE.live_tint.clear()
		end

		if ENGINE.pools then
			ENGINE.pools.clear()
		end
	end

	if status == "exit" and state_name == "StateGameplay" then
		EFFECT_PACKAGES.release_when_idle()

		if ENGINE.scene_lights then
			ENGINE.scene_lights.clear()
		end
	elseif status == "exit" and state_name == "StateGame" then
		EFFECT_PACKAGES.release_now()
	end

	if status == "enter" and state_name == "GameplayStateRun" and ENGINE.colour_channels then
		ENGINE.colour_channels.write(true)
	end

end

mod.on_settings_reset = function()
	cache_settings()
	EFFECT_PACKAGES.set_enabled(mod:get("effect_packages_enabled") ~= false)
end

startup_detail.mark()
cache_settings()
startup_detail.lap("other", "settings")

diagnostics = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/Polychromatic_debug")({
	mod = mod,
	redirects = REDIRECTS,
	payload_root = MODULES_ROOT,
	soul_slots = SOUL_SLOTS,
	glow_slots = GLOW_SLOTS,
	sets = SETS,
	asset_redirect = asset_redirect,
	redirect_library = REDIRECT_LIBRARY,
	redirect_handles = _redirect_handles,
	redirect_served = redirect_served,
	profile_for = profile_for,
	redshift_owns_sniper = redshift_owns_sniper,
	effect_stats = _effect_stats,
	registry = REGISTRY,
	effect_packages = EFFECT_PACKAGES,
	engines_loaded = ENGINE,
	engines_disabled = ENGINE_DISABLED,
	engine_known = ENGINE_LIB.known,
	routing_gaps = function()
		local gaps, seen = {}, {}

		for _, manifest in ipairs(REGISTRY.modules) do
			for _, kind in ipairs({ "encoded_effects", "ca_palettes", "glow_particle_palettes" }) do
				local part = module_data_file(manifest, kind)

				for _, entry in pairs(type(part) == "table" and part or {}) do
					local set_id = type(entry) == "table" and entry.set or entry
					local engine = set_id == "force_staff" and "staff_routing" or set_id == "psyker_blitz" and "blitz_routing" or nil
					local key = engine and manifest.id .. "/" .. set_id

					if engine and not ENGINE[engine] and not seen[key] then
						seen[key] = true
						gaps[#gaps + 1] = { module = manifest.id, set = set_id, engine = engine }
					end
				end
			end
		end

		return gaps
	end,
	colour_channels = function()
		return ENGINE.colour_channels and ENGINE.colour_channels.report() or {}
	end,
	flags = function()
		return {
			gameplay_running = STATE.gameplay_running,
			burn_patch_served = _burn_patch_served,
			soulblaze = _soulblaze_enabled,
			flamer_burn = _flamer_burn_enabled,
			skull_burn = _skull_burn_enabled,
			debug_logging = _debug_logging,
		}
	end,
})

startup_detail.lap("other", "diagnostics")

if REDIRECTS[1] then
	mod:hook_safe(CLASS.PackageManager, "load", function(self, package_name, reference_name, callback, prioritize, use_resident_loading)
		if _debug_logging then
			diagnostics.package_loaded(package_name, reference_name, prioritize, use_resident_loading)
		end
	end)
end

mod:command("poly_check", mod:localize("poly_check_description"), function()
	diagnostics.check_setup(false)
end)

mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/options_labels")(mod, {
	has_sniper = has_source("sniper"),
	redshift_owns_sniper = redshift_owns_sniper,
})

startup_detail.lap("other", "labels")

mod.on_all_mods_loaded = function()
	local load_timer = STARTUP.start()

	mod:info("Polychromatic %s loaded", tostring(mod.version))

	local ui = Managers.ui
	local in_level = ui ~= nil and ui:get_current_sub_state_name() == "GameplayStateRun"

	STATE.gameplay_running = in_level

	if not _booted and ui ~= nil and ui:get_current_state_name() == "StateGameplay" then
		run_after_boot()
	end

	if _material_format.missing then
		mod:info("material format probe %s unreadable: every patched file stays stock", _material_format.probe)
		mod:echo("%s", mod:localize("game_format_unknown"))
	elseif not _material_format.ok then
		mod:info("game material format %s, payload built for %s: every patched file stays stock", tostring(_material_format.found), tostring(_material_format.expected))
		mod:echo("%s", mod:localize("game_format_changed"))
	end

	load_timer.mark()

	if asset_redirect then
		asset_redirect.commit()
	end

	load_timer.lap("redirect commit")
	_redirects_waiting = true

	if not asset_redirect or asset_redirect.ready() then
		settle_redirects()
	end

	load_timer.mark()

	if STATE.gameplay_running and ENGINE.weapon_glow then
		ENGINE.weapon_glow.track_existing()
	end

	load_timer.lap("engine attach")
	load_timer.mark()

	EFFECT_PACKAGES.startup()

	load_timer.lap("host start")
	mod:info("%s", load_timer.line("all mods loaded", { "redirect commit", "engine attach", "host start" }))

	if _debug_logging and _redirects_settled and not _redirects_capped then
		diagnostics.check_setup(true, true)
	elseif _debug_logging then
		_setup_after_settle = true
	end
end

mod.on_unload = function(exit_game)
	local managers = rawget(_G, "Managers")
	local package_manager = managers and managers.package

	if exit_game and package_manager and not rawget(package_manager, "__deleted") then
		EFFECT_PACKAGES.release_now()
	end

	for _, name in ipairs({ "weapon_glow", "unit_hues", "decal_swap" }) do
		local engine = ENGINE[name]

		if engine then
			local ok, err = pcall(engine.restore)

			if not ok then
				mod:info("%s restore failed: %s", name, tostring(err))
			end
		end
	end

	if ENGINE.colour_channels then
		ENGINE.colour_channels.detach()
		ENGINE.colour_channels.restore()
	end

	if ENGINE.scene_lights then
		ENGINE.scene_lights.clear()
	end
end

mod.on_setting_changed = function(setting_id)
	local was_logging = _debug_logging

	cache_settings()

	if ENGINE.weapon_glow then
		ENGINE.weapon_glow.refresh()
	end

	if ENGINE.unit_hues then
		ENGINE.unit_hues.refresh()
	end

	if ENGINE.weapon_glow then
		ENGINE.weapon_glow.restart_loops(setting_id)
	end

	if ENGINE.colour_channels then
		ENGINE.colour_channels.write(true)
	end

	if setting_id == "effect_packages_enabled" then
		EFFECT_PACKAGES.set_enabled(mod:get("effect_packages_enabled") ~= false)
	end

	if setting_id == "debug_logging" and _debug_logging and not was_logging then
		diagnostics.check_setup(true, true)
	end
end

mod:info("%s", file_timer.line("file scope", { "registry", "bake", "engines", "redirects register" }))
mod:info("%s", startup_detail.line())
