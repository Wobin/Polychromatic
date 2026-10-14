return function(mod, core, data_list)
	local murmur_preimage = core.murmur_preimage
	local WEAPONS = {}
	local SLOTS = {}
	local DEFAULT_SLOTS = { "slot_primary", "slot_secondary" }
	local _slot_listed = {}

	for _, data in ipairs(data_list) do
		for _, weapon in ipairs(data.weapons or {}) do
			if type(weapon.fins) == "string" then
				weapon.fins = core.data(weapon.fins)
			end

			if type(weapon.slots) ~= "table" then
				weapon.slots = DEFAULT_SLOTS
			end

			weapon.on_slot = {}

			for _, slot_name in ipairs(weapon.slots) do
				weapon.on_slot[slot_name] = true

				if not _slot_listed[slot_name] then
					_slot_listed[slot_name] = true
					SLOTS[#SLOTS + 1] = slot_name
				end
			end

			if type(weapon.attachments) == "table" then
				weapon.attachment_names = {}

				for _, name in ipairs(weapon.attachments) do
					weapon.attachment_names[name] = true
				end
			end

			WEAPONS[#WEAPONS + 1] = weapon
		end
	end

	local RAINBOW_INTERVAL = 0.1

	local ipairs = ipairs
	local pairs = pairs
	local rawget = rawget
	local type = type
	local math_floor = math.floor
	local math_max = math.max
	local string_find = string.find
	local string_match = string.match
	local Application_can_get_resource = Application.can_get_resource
	local Unit_alive = Unit.alive
	local Unit_debug_name = Unit.debug_name
	local Unit_set_material = Unit.set_material
	local Unit_set_vector3_for_materials = Unit.set_vector3_for_materials

	local _tracked = setmetatable({}, { __mode = "k" })
	local _fin_owner = setmetatable({}, { __mode = "k" })
	local _unit_count = setmetatable({}, { __mode = "k" })
	local _written = setmetatable({}, { __mode = "k" })
	local _fin_attached = setmetatable({}, { __mode = "k" })
	local _fin_ready = {}
	local _stock_names = {}
	local _units_scratch = {}
	local _rainbow_t = 0
	local glow = {}

	local function stock_name(hex)
		local name = _stock_names[hex]

		if name == nil then
			name = murmur_preimage and murmur_preimage(hex) or false

			if name and Application_can_get_resource("material", name) ~= true then
				name = false
			end

			_stock_names[hex] = name
		end

		return name or nil
	end

	local function usable(extension)
		return extension ~= nil and not rawget(extension, "__deleted")
	end

	local function weapon_for(slot, slot_name)
		local item = slot and slot.item
		item = item and (item.item or item)

		local name = item and item.name

		if type(name) ~= "string" then
			return nil
		end

		for i = 1, #WEAPONS do
			local weapon = WEAPONS[i]

			if weapon.on_slot[slot_name] and string_find(name, weapon.pattern, 1, true) then
				return weapon
			end
		end

		return nil
	end

	local function colour_for(profile, stock, t)
		local mode = profile and profile.mode

		if not mode or mode == "stock" then
			return stock[1], stock[2], stock[3]
		end

		if mode == "hidden" then
			return 0, 0, 0
		end

		local hue = profile.hue or 0
		local saturation = profile.saturation or 1

		if mode == "rainbow" then
			local phase = t * core.RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
			saturation = 1
		end

		local peak = math_max(stock[1], stock[2], stock[3])
		local value = peak * (profile.brightness or core.STOCK_BRIGHTNESS_STEP) / core.STOCK_BRIGHTNESS_STEP

		return core.hsv_to_rgb(hue, saturation, value)
	end

	local function named_units(units, by_unit, map_by_unit, names)
		if type(by_unit) ~= "table" or type(map_by_unit) ~= "table" then
			return
		end

		for root, list in pairs(by_unit) do
			local map = map_by_unit[root]

			if type(map) == "table" then
				for i = 1, #list do
					local unit = list[i]
					local name = map[unit]

					if name ~= nil and names[name] then
						units[#units + 1] = unit
					end
				end
			end
		end
	end

	local function append_attachments(units, by_unit)
		if type(by_unit) ~= "table" then
			return
		end

		for _, list in pairs(by_unit) do
			for i = 1, #list do
				units[#units + 1] = list[i]
			end
		end
	end

	local function slot_units(slot, weapon)
		local units = _units_scratch
		local names = weapon.attachment_names

		for i = #units, 1, -1 do
			units[i] = nil
		end

		if names then
			named_units(units, slot.attachments_by_unit_1p, slot.attachment_map_by_unit_1p, names)
			named_units(units, slot.attachments_by_unit_3p, slot.attachment_map_by_unit_3p, names)

			return units
		end

		if slot.unit_1p then
			units[#units + 1] = slot.unit_1p
		end

		if slot.unit_3p then
			units[#units + 1] = slot.unit_3p
		end

		append_attachments(units, slot.attachments_by_unit_1p)
		append_attachments(units, slot.attachments_by_unit_3p)

		return units
	end

	local function swap_fins(units, weapon, owner)
		local category = owner == "mine" and "mine" or "team"

		for i = 1, #units do
			local unit = units[i]

			if unit and Unit_alive(unit) and _fin_owner[unit] ~= category then
				local id = string_match(tostring(Unit_debug_name(unit)), "%[(%x+)%]")
				local entries = id and weapon.fins[id]
				local done = true

				if entries then
					local generation = core.package_generation()

					for k = 1, #entries do
						local name = weapon.fin_root .. entries[k].material .. "_" .. category
						local ready = _fin_ready[name]

						if ready ~= true and ready ~= generation then
							ready = Application_can_get_resource("material", name) == true or generation
							_fin_ready[name] = ready
						end

						if ready == true then
							_fin_attached[unit] = entries
							Unit_set_material(unit, entries[k].slot, name)
						else
							done = false
						end
					end
				end

				if done then
					_fin_owner[unit] = category
				end
			end
		end
	end

	local function record(unit, variable_name, r, g, b)
		local entry = _written[unit]

		if not entry then
			entry = {}
			_written[unit] = entry
		end

		entry.variable = variable_name
		entry[1], entry[2], entry[3] = r, g, b
	end

	local function write_units(units, variable_name, r, g, b)
		local colour = Vector3(r, g, b)

		for i = 1, #units do
			local unit = units[i]

			if unit and Unit_alive(unit) then
				Unit_set_vector3_for_materials(unit, variable_name, colour, true)
				record(unit, variable_name, r, g, b)
			end
		end
	end

	local function apply_slot(slot, weapon, owner, t, units)
		local profile = core.profile_for(weapon.set, owner)

		units = units or slot_units(slot, weapon)

		if weapon.fins then
			swap_fins(units, weapon, owner)
		end

		for _, variable in ipairs(weapon.variables) do
			local r, g, b = colour_for(profile, variable.stock, t)

			write_units(units, variable.name, r, g, b)
		end

		if weapon.attachment_names then
			_unit_count[slot] = #units
		end
	end

	function glow.apply(extension)
		if not usable(extension) then
			return
		end

		local unit = extension._unit
		local equipment = extension._equipment

		if not unit or not equipment or not Unit_alive(unit) then
			return
		end

		local owner = core.player_category(unit)
		local t = core.gameplay_time()
		local found = false

		for _, slot_name in ipairs(SLOTS) do
			local slot = equipment[slot_name]
			local weapon = weapon_for(slot, slot_name)

			if weapon then
				found = true
				apply_slot(slot, weapon, owner, t)
			end
		end

		if found then
			_tracked[extension] = true
		else
			_tracked[extension] = nil
		end
	end

	function glow.refresh()
		for extension in pairs(_tracked) do
			glow.apply(extension)
		end
	end

	local function setting_set(setting_id)
		if type(setting_id) ~= "string" then
			return nil
		end

		for i = 1, #WEAPONS do
			local set = WEAPONS[i].set

			if string_find(setting_id, "^" .. set .. "_mine_") or string_find(setting_id, "^" .. set .. "_team_") then
				return set
			end
		end

		return nil
	end

	function glow.restart_loops(setting_id)
		local changed = setting_set(setting_id)

		if not changed then
			return
		end

		for extension in pairs(_tracked) do
			local equipment = usable(extension) and extension._equipment
			local unit = equipment and extension._unit

			if equipment and unit and Unit_alive(unit) and extension.wieldable_slot_scripts_from_slot then
				for _, slot_name in ipairs(SLOTS) do
					local weapon = weapon_for(equipment[slot_name], slot_name)

					if weapon and weapon.set == changed then
						local scripts = extension:wieldable_slot_scripts_from_slot(slot_name)

						for _, script in ipairs(scripts or {}) do
							if script._stop_vfx_loop and script._looping_effect_id and script:_looping_effect_id() then
								script:_stop_vfx_loop(true)
							end
						end
					end
				end
			end
		end
	end

	function glow.restore()
		for extension in pairs(_tracked) do
			local live = usable(extension)
			local unit = live and extension._unit
			local equipment = live and extension._equipment

			if unit and equipment and Unit_alive(unit) then
				for _, slot_name in ipairs(SLOTS) do
					local slot = equipment[slot_name]
					local weapon = weapon_for(slot, slot_name)

					if weapon then
						local units = slot_units(slot, weapon)

						for _, variable in ipairs(weapon.variables) do
							write_units(units, variable.name, variable.stock[1], variable.stock[2], variable.stock[3])
						end

						_unit_count[slot] = nil
					end
				end
			end

			_tracked[extension] = nil
		end

		for unit in pairs(_written) do
			_written[unit] = nil
		end

		for unit, entries in pairs(_fin_attached) do
			local restored = true

			if Unit_alive(unit) then
				for k = 1, #entries do
					local name = stock_name(entries[k].material)

					if not name or not pcall(Unit_set_material, unit, entries[k].slot, name) then
						restored = false
					end
				end
			end

			if restored then
				_fin_attached[unit] = nil
			end

			_fin_owner[unit] = nil
		end

		if next(_fin_attached) ~= nil then
			mod:info("plasma fins: a stock fin material could not be resolved, package materials stay attached")
		end
	end

	function glow.in_use()
		for unit in pairs(_fin_attached) do
			if Unit_alive(unit) then
				return true
			end

			_fin_attached[unit] = nil
		end

		return false
	end

	function glow.written(unit)
		local entry = unit and _written[unit]

		if not entry then
			return nil
		end

		return entry.variable, entry[1], entry[2], entry[3]
	end

	local function apply(extension)
		glow.apply(extension)
	end

	mod:hook_safe(CLASS.PlayerUnitVisualLoadoutExtension, "_equip_item_to_slot", apply)
	mod:hook_safe(CLASS.PlayerHuskVisualLoadoutExtension, "_equip_item_to_slot", apply)
	mod:hook_safe(CLASS.PlayerUnitVisualLoadoutExtension, "wield_slot", apply)
	mod:hook_safe(CLASS.PlayerHuskVisualLoadoutExtension, "wield_slot", apply)

	function glow.track_existing()
		local player_manager = Managers.player

		if not player_manager or rawget(player_manager, "__deleted") then
			return
		end

		local players = player_manager:players()

		for _, player in pairs(players or {}) do
			local unit = player.player_unit
			local extension = unit and Unit_alive(unit) and ScriptUnit.has_extension(unit, "visual_loadout_system")

			if extension then
				glow.apply(extension)
			end
		end
	end

	function glow.update(dt)
		_rainbow_t = _rainbow_t + dt

		if _rainbow_t < RAINBOW_INTERVAL then
			return
		end

		_rainbow_t = 0

		for extension in pairs(_tracked) do
			local live = usable(extension)
			local unit = live and extension._unit

			if unit and Unit_alive(unit) then
				local owner = core.player_category(unit)
				local equipment = extension._equipment

				for _, slot_name in ipairs(SLOTS) do
					local slot = equipment and equipment[slot_name]
					local weapon = weapon_for(slot, slot_name)
					local profile = weapon and core.profile_for(weapon.set, owner)

					if weapon and weapon.fins then
						swap_fins(slot_units(slot, weapon), weapon, owner)
					end

					if profile and profile.mode == "rainbow" then
						apply_slot(slot, weapon, owner, core.gameplay_time())
					elseif weapon and weapon.attachment_names then
						local units = slot_units(slot, weapon)

						if #units ~= _unit_count[slot] then
							apply_slot(slot, weapon, owner, core.gameplay_time(), units)
						end
					end
				end
			else
				_tracked[extension] = nil
			end
		end
	end

	return glow
end
