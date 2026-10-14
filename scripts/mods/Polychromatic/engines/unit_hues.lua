return function(mod, core, data_list)
	local murmur_preimage = core.murmur_preimage
	local HUES = 12
	local THRESHOLD_SETTINGS = { mine = "shield_mine_damage_threshold", team = "shield_team_damage_threshold" }
	local UNITS = {}
	local SMOKE_UNITS = {}

	for _, data in ipairs(data_list) do
		for target, part in pairs({ [UNITS] = data.units, [SMOKE_UNITS] = data.smoke_units }) do
			for key, value in pairs(part) do
				if target[key] == nil then
					target[key] = value
				end
			end
		end
	end

	local ipairs = ipairs
	local math_floor = math.floor
	local string_format = string.format
	local string_match = string.match
	local tostring = tostring
	local type = type
	local Unit_alive = Unit.alive
	local Unit_debug_name = Unit.debug_name
	local Unit_set_material = Unit.set_material

	local _ready = {}
	local _failed = false
	local _names = {}
	local _entry_of = setmetatable({}, { __mode = "k" })
	local _applied = setmetatable({}, { __mode = "k" })
	local _owner = setmetatable({}, { __mode = "k" })
	local _attached = setmetatable({}, { __mode = "k" })
	local _smoke_copies = setmetatable({}, { __mode = "k" })
	local _smoke_pending = false
	local _stock_names = {}
	local _threshold = { mine = 0, team = 0 }
	local _damaged_hue = {}
	local hues = {}

	local function stock_name(hex)
		local name = _stock_names[hex]

		if name == nil then
			name = murmur_preimage and murmur_preimage(hex) or false

			if name and Application.can_get_resource("material", name) ~= true then
				name = false
			end

			_stock_names[hex] = name
		end

		return name or nil
	end

	local function names_for(entry)
		local names = _names[entry]

		if not names then
			names = {}

			for i = 0, HUES - 1 do
				names[i] = string_format("%s%s_h%02d", entry.root, entry.material, i)
			end

			_names[entry] = names
		end

		return names
	end

	local function entry_for(unit)
		local entry = _entry_of[unit]

		if entry == nil then
			local id = string_match(tostring(Unit_debug_name(unit)), "%[(%x+)%]")

			entry = id and UNITS[id] or false
			_entry_of[unit] = entry
		end

		return entry
	end

	local function hue_index(hue)
		return math_floor(hue * HUES + 0.5) % HUES
	end

	local function wanted_index(entry, category, health)
		local profile = core.profile_for(entry.set, category)

		if not profile or not profile.show then
			return nil
		end

		local threshold = entry.gate and _threshold[category] or 0

		if threshold > 0 then
			local percent = health and health.current_health_percent and health:current_health_percent()

			if percent and percent * 100 < threshold then
				return hue_index(_damaged_hue[category] or 0)
			end
		end

		local mode = profile.mode

		if mode == "rainbow" then
			local phase = core.gameplay_time() * core.RAINBOW_CYCLES_PER_SECOND

			return hue_index(phase - math_floor(phase))
		elseif mode == "custom" then
			return hue_index(profile.hue or 0)
		end

		return nil
	end

	function hues.update(key, unit, owner_unit, health)
		if not unit or not Unit_alive(unit) then
			return
		end

		local entry = entry_for(unit)

		if not entry then
			return
		end

		local category = _owner[key]

		if not category then
			category = core.player_category(owner_unit or unit)
			_owner[key] = category
		end

		local index = wanted_index(entry, category, health)

		if index == nil or _applied[key] == index then
			return
		end

		local name = names_for(entry)[index]

		if not core.resource_ready(_ready, name, "material", name) then
			return
		end

		_attached[unit] = entry
		Unit_set_material(unit, entry.slot, name)
		_applied[key] = index
	end

	function hues.restore()
		for unit, entry in pairs(_attached) do
			local name = Unit_alive(unit) and stock_name(entry.material)

			if name then
				if pcall(Unit_set_material, unit, entry.slot, name) then
					_attached[unit] = nil
				end
			elseif not Unit_alive(unit) then
				_attached[unit] = nil
			end
		end

		for key in pairs(_applied) do
			_applied[key] = nil
		end

		if hues.in_use() then
			mod:info("shield and smoke colour: package resources are still attached after restore")
		end
	end

	function hues.in_use()
		for _, list in ipairs({ _attached, _smoke_copies }) do
			for unit in pairs(list) do
				if Unit_alive(unit) then
					return true
				end

				list[unit] = nil
			end
		end

		return false
	end

	function hues.smoke_unit(unit_name, owner_unit)
		local smoke = SMOKE_UNITS[unit_name]

		if not smoke then
			return unit_name
		end

		local names = core.unit_slots(smoke.slots)
		local index = names and wanted_index(smoke, core.player_category(owner_unit), nil)
		local name = index and names[index + 1]

		if not name or not core.resource_ready(_ready, name, "unit", name) then
			return unit_name
		end

		return name
	end

	function hues.refresh()
		for _, category in ipairs({ "mine", "team" }) do
			local threshold = mod:get(THRESHOLD_SETTINGS[category])

			if mod:get("shield_" .. category .. "_damage_gate") ~= true then
				_threshold[category] = 0
			else
				_threshold[category] = type(threshold) == "number" and threshold or 50
			end

			local colour = mod:get("shield_" .. category .. "_damaged_colour")

			if type(colour) == "table" then
				_damaged_hue[category] = core.rgb_to_hsv((colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255)
			else
				_damaged_hue[category] = 0
			end
		end
	end

	local function guarded(func, fallback, ...)
		if _failed then
			return fallback
		end

		local ok, result = pcall(func, ...)

		if not ok then
			_failed = true
			mod:info("shield and smoke colour disabled for this session: %s", core.with_traceback(result))

			return fallback
		end

		return result
	end

	mod:hook_safe(CLASS.PsykerForceFieldUnitExtension, "update", function(self, unit)
		guarded(hues.update, nil, self, unit, self.owner_unit, self._health_extension)
	end)

	local smoke_template = require("scripts/extension_systems/unit_templates/smoke_fog_unit_template")

	mod:hook(smoke_template, "local_unit", function(func, unit_name, position, rotation, material, husk_unit_name, placed_on_unit, owner_unit, ...)
		local name, spawn_position, spawn_rotation = func(unit_name, position, rotation, material, husk_unit_name, placed_on_unit, owner_unit, ...)
		local spawn_name = guarded(hues.smoke_unit, name, name, owner_unit)

		_smoke_pending = spawn_name ~= name

		return spawn_name, spawn_position, spawn_rotation
	end)

	mod:hook(smoke_template, "husk_unit", function(func, session, object_id)
		local name, spawn_position, spawn_rotation = func(session, object_id)
		local owner_id = GameSession.game_object_field(session, object_id, "owner_unit_id")
		local spawner = Managers.state.unit_spawner
		local owner_unit = owner_id ~= NetworkConstants.invalid_game_object_id and spawner and spawner:unit(owner_id) or nil
		local spawn_name = guarded(hues.smoke_unit, name, name, owner_unit)

		_smoke_pending = spawn_name ~= name

		return spawn_name, spawn_position, spawn_rotation
	end)

	local function remember_smoke(unit)
		if _smoke_pending and unit then
			_smoke_copies[unit] = true
		end

		_smoke_pending = false
	end

	mod:hook_safe(smoke_template, "local_init", remember_smoke)
	mod:hook_safe(smoke_template, "husk_init", remember_smoke)

	hues.refresh()

	return hues
end
