local math_floor = math.floor

return function(mod, core, data_list)
	local profile_for = core.profile_for
	local gameplay_time = core.gameplay_time
	local resource_ready = core.resource_ready
	local RAINBOW_CYCLES_PER_SECOND = core.RAINBOW_CYCLES_PER_SECOND

	local DECAL_HUES = 12
	local DECAL_ROOT = nil

	for _, data in ipairs(data_list) do
		if DECAL_ROOT == nil and type(data.root) == "string" then
			DECAL_ROOT = data.root
		end
	end

	local DECAL_SLOTS = {
		["4cfe07db41751aed"] = {
			{ slot = "\xe2\xb4\x2f\xd0\xd7\xf4\x23\x92", material = "56ad1542a80541ae" },
			{ slot = "\xb4\x3e\x5f\x4a\x6d\xef\xff\xc6", material = "6f5d444e780d91c3" },
		},
		["fc709e56062454db"] = {
			{ slot = "\xe2\xb4\x2f\xd0\xd7\xf4\x23\x92", material = "2343ac2a54c7b237" },
			{ slot = "\xb4\x3e\x5f\x4a\x6d\xef\xff\xc6", material = "6f5d444e780d91c3" },
		},
	}
	local _decal_hue = setmetatable({}, { __mode = "k" })
	local _decal_names = {}
	local _decal_ready = {}

	local function recolour_targeting_decal(script, owner)
		local unit = script._decal_unit

		if not DECAL_ROOT or not unit or not Unit.alive(unit) then
			return
		end

		local profile = profile_for("staff_trauma", owner)
		local mode = profile and profile.show and profile.mode

		if mode ~= "custom" and mode ~= "rainbow" then
			return
		end

		local hue = profile.hue or 0

		if mode == "rainbow" then
			local phase = gameplay_time() * RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
		end

		local index = math_floor(hue * DECAL_HUES + 0.5) % DECAL_HUES

		if _decal_hue[unit] == index then
			return
		end

		local id = string.match(tostring(Unit.debug_name(unit)), "%[(%x+)%]")
		local slots = id and DECAL_SLOTS[id]

		if not slots then
			_decal_hue[unit] = index

			return
		end

		local names = _decal_names[slots]

		if not names then
			names = {}

			for i = 1, #slots do
				names[i] = {}

				for hue_index = 0, DECAL_HUES - 1 do
					names[i][hue_index] = string.format("%s%s_h%02d", DECAL_ROOT, slots[i].material, hue_index)
				end
			end

			_decal_names[slots] = names
		end

		for i = 1, #slots do
			if not resource_ready(_decal_ready, names[i][index], "material", names[i][index]) then
				return
			end
		end

		for i = 1, #slots do
			Unit.set_material(unit, slots[i].slot, names[i][index])
		end

		_decal_hue[unit] = index
	end

	return {
		recolour = recolour_targeting_decal,
	}
end
