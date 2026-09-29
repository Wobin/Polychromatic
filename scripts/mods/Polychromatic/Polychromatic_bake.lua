return function(context)
	local mod = context.mod
	local math_floor = math.floor
	local math_max = math.max
	local math_min = math.min
	local REDIRECTS = context.redirects
	local SOUL_SLOTS = context.soul_slots
	local MIN_BRIGHTNESS_STEP = context.min_brightness
	local STOCK_BRIGHTNESS_STEP = context.stock_brightness
	local MAX_BRIGHTNESS_STEP = context.max_brightness

	local SOUL_PAYLOAD_DIR = "../mods/Polychromatic/payload/"
	local SOUL_TEMPLATE_FILE = "soulblaze_flame.template"
	local SOUL_TEMPLATE_SIZE = 244
	local SOUL_VALUE_OFFSET = 220
	local SOUL_HUE_STEPS = 1024
	local SOUL_SATURATION_STEPS = 15
	local BURN_LAYERS = {
		{ template = "burn_0.burntemplate", size = 244, offset = 220 },
		{ template = "burn_1.burntemplate", size = 312, offset = 272 },
		{ template = "burn_2.burntemplate", size = 508, offset = 460 },
	}
	local BURN_PALETTE_SLOTS = 12

	local function burn_material_file(layer, slot)
		return string.format("burn_%d_%02d.burnmat", layer - 1, slot - 1)
	end

	local function burn_material_loose(layer, slot)
		return string.format("data/zz/f0f5000000001%x%02x", layer - 1, slot - 1)
	end

	local function soul_material_file(slot)
		return string.sub(slot.material, 9) .. ".soulmat"
	end

	local function soul_bake_profile()
		for _, category in ipairs({ "mine", "team" }) do
			local prefix = "staff_" .. category .. "_"
			local mode = mod:get(prefix .. "mode") or "stock"

			if mod:get(prefix .. "show") ~= false and mode ~= "stock" then
				local saturation = 1
				local colour = mod:get(prefix .. "colour")

				if mode ~= "rainbow" and type(colour) == "table" then
					local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
					local high = math_max(r, g, b)

					saturation = high > 0 and (high - math_min(r, g, b)) / high or 0
				end

				return saturation, mod:get(prefix .. "brightness") or STOCK_BRIGHTNESS_STEP
			end
		end

		return 1, STOCK_BRIGHTNESS_STEP
	end

	local GLOW_TEMPLATE_FILE = "0937ecdd02b49a51.glowtemplate"
	local GLOW_MATERIAL_FILE = "0937ecdd02b49a51.glowmat"
	local GLOW_TEMPLATE_SIZE = 308
	local GLOW_VALUE_OFFSET = 264

	local IMPACT_GLOW_TEMPLATE_FILE = "7082301abe176951.impactglowtemplate"
	local IMPACT_GLOW_FILE = "7082301abe176951.impactglow"
	local IMPACT_GLOW_SIZE = 374957
	local IMPACT_GLOW_OFFSET = 244

	local function bake_impact_glow()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			return
		end

		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. IMPACT_GLOW_TEMPLATE_FILE, "rb")

		if not template_file then
			mod:info("las impact glow: template missing, shipped default used")

			return
		end

		local template = template_file:read("*a")

		template_file:close()

		if not template or #template ~= IMPACT_GLOW_SIZE then
			return
		end

		local value = ffi.new("float[1]", 1000)
		local mode = mod:get("las_mine_mode")

		if mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow") then
			local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
			local hue, saturation = 0, 0

			if mode == "custom" then
				local colour = mod:get("las_mine_colour")

				if type(colour) == "table" then
					local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
					local high, low = math_max(r, g, b), math_min(r, g, b)

					saturation = high > 0 and (high - low) / high or 0

					if high > low then
						if high == r then
							hue = ((g - b) / (high - low)) / 6
						elseif high == g then
							hue = (2 + (b - r) / (high - low)) / 6
						else
							hue = (4 + (r - g) / (high - low)) / 6
						end

						hue = hue - math_floor(hue)
					end
				end
			end

			local hue_step = math_floor(hue * 1024) % 1024
			local saturation_step = math_floor(saturation * 15 + 0.5)

			value[0] = 1000 + saturation_step + (hue_step * 16 + brightness) / 16384
		end

		local bytes = string.sub(template, 1, IMPACT_GLOW_OFFSET) .. ffi.string(value, 4) .. string.sub(template, IMPACT_GLOW_OFFSET + 5)
		local path = SOUL_PAYLOAD_DIR .. IMPACT_GLOW_FILE
		local existing = lua_io.open(path, "rb")
		local current = existing and existing:read("*a")

		if existing then
			existing:close()
		end

		if current ~= bytes then
			local out = lua_io.open(path, "wb")

			if out then
				out:write(bytes)
				out:close()
			else
				mod:info("las impact glow: cannot write %s, shipped default used", path)
			end
		end
	end

	local GLOW_SLOTS = {
		muzzle = {
			{
				package = "content/fx/particles/debug/fx_debug_1m_blue",
				bundle = "6c363592a35f5599",
				bundle_sha256 = "8ab4b5e21781b700051df420a400b0f3ae028ca7d272640eb38571936f405c4f",
				material = "f0f0000000000007",
				virtual_path = "data/zz/f0f0000000000007",
			},
			{
				package = "content/fx/particles/debug/fx_debug_1m_red",
				bundle = "88cedce8a498f97e",
				bundle_sha256 = "4dea34a5d7d323d046af778991c008e2352982a0d2b8106cf1860566d8bc0f96",
				material = "f0f0000000000008",
				virtual_path = "data/zz/f0f0000000000008",
			},
			{
				package = "content/fx/particles/debug/fx_debug_1m_green",
				bundle = "d932eac771ff85ae",
				bundle_sha256 = "38d3c5c84bab2547f5ecd0c17d2f0658295f4ffd137b2a828a149404d58ee782",
				material = "f0f0000000000009",
				virtual_path = "data/zz/f0f0000000000009",
			},
			{
				package = "content/fx/particles/impacts/flesh/blood_splatter_01_old",
				bundle = "81686d16269ea030",
				bundle_sha256 = "89d512bf2f590d966944fa3cd71d3ce262f7ac8aad3b9e789f46731cd29c8cd1",
				material = "f0f000000000000a",
				virtual_path = "data/zz/f0f000000000000a",
			},
			{
				package = "content/fx/particles/impacts/flesh/blood_fountain_head_01_old",
				bundle = "43fcfaba468316d8",
				bundle_sha256 = "8a0c6162946fcb7e99f43ccecac541773b9ace84973ce0fea77c3d3271426e1b",
				material = "f0f000000000000b",
				virtual_path = "data/zz/f0f000000000000b",
			},
			{
				package = "content/fx/particles/impacts/weapons/autogun/autogun_impact_02_old",
				bundle = "ff966c81581e8207",
				bundle_sha256 = "0146e4e7e09303bdcafaf56305ba6dcdb64328fa826432ddc64bea2520524998",
				material = "f0f000000000000c",
				virtual_path = "data/zz/f0f000000000000c",
			},
		},
	}

	local GLOW_SOURCE_EFFECTS = {
		["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle"] = "muzzle",
	}
	local GLOW_IMPACT_TEMPLATE = "7082301abe176951.impactglowtemplate"
	local GLOW_MUZZLE_TEMPLATE = "0937ecdd02b49a51.glowtemplate"
	local GLOW_IMPACT_SIZE, GLOW_IMPACT_OFFSET = 374957, 244
	local GLOW_MUZZLE_SIZE, GLOW_MUZZLE_OFFSET = 308, 264

	local function glow_hsv_rgb(h, s, v)
		local i = math_floor(h * 6) % 6
		local f = h * 6 - math_floor(h * 6)
		local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))

		if i == 0 then
			return v, t, p
		elseif i == 1 then
			return q, v, p
		elseif i == 2 then
			return p, v, t
		elseif i == 3 then
			return p, q, v
		elseif i == 4 then
			return t, p, v
		end

		return v, p, q
	end

	local function glow_hue_of(list, index)
		return (index - 1) / #list
	end

	local function bake_glow_palette()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			return
		end

		local mode = mod:get("las_mine_mode")
		local shown = mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
		local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local saturation_step = 15

		if mode == "custom" then
			local colour = mod:get("las_mine_colour")

			if type(colour) == "table" then
				local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
				local high, low = math_max(r, g, b), math_min(r, g, b)

				saturation_step = math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)
			end
		end

		for layer, list in pairs(GLOW_SLOTS) do
			local template_name = layer == "impact" and GLOW_IMPACT_TEMPLATE or GLOW_MUZZLE_TEMPLATE
			local size = layer == "impact" and GLOW_IMPACT_SIZE or GLOW_MUZZLE_SIZE
			local offset = layer == "impact" and GLOW_IMPACT_OFFSET or GLOW_MUZZLE_OFFSET
			local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. template_name, "rb")
			local template = template_file and template_file:read("*a")

			if template_file then
				template_file:close()
			end

			if template and #template == size then
				for i = 1, #list do
					local hue = glow_hue_of(list, i)
					local patch

					if not shown then
						patch = nil
					elseif layer == "impact" then
						local value = ffi.new("float[1]")

						value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
						patch = ffi.string(value, 4)
					else
						local r, g, b = glow_hsv_rgb(hue, saturation_step / 15, brightness / STOCK_BRIGHTNESS_STEP)
						local rgb = ffi.new("float[3]", r, g, b)

						patch = ffi.string(rgb, 12)
					end

					local bytes = template

					if patch then
						bytes = string.sub(template, 1, offset) .. patch .. string.sub(template, offset + #patch + 1)
					end

					local path = SOUL_PAYLOAD_DIR .. list[i].material .. ".glowpal"
					local existing = lua_io.open(path, "rb")
					local current = existing and existing:read("*a")

					if existing then
						existing:close()
					end

					if current ~= bytes then
						local out = lua_io.open(path, "wb")

						if out then
							out:write(bytes)
							out:close()
						else
							mod:info("las glow palette: cannot write %s", path)
						end
					end
				end
			end
		end
	end

	local SURFACE_BAKED = {
		{ template = "f0f0000000000101.surftemplate", file = "f0f0000000000101.glowpal", size = 393660, offset = 244 },
		{ template = "f0f0000000000102.surftemplate", file = "f0f0000000000102.glowpal", size = 374989, offset = 244 },
	}

	local function bake_surface_glow()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			return
		end

		local mode = mod:get("las_mine_mode")
		local shown = mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
		local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local hue, saturation_step = 0, 0

		if mode == "custom" then
			local colour = mod:get("las_mine_colour")

			if type(colour) == "table" then
				local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
				local high, low = math_max(r, g, b), math_min(r, g, b)

				saturation_step = math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)

				if high > low then
					if high == r then
						hue = ((g - b) / (high - low)) / 6
					elseif high == g then
						hue = (2 + (b - r) / (high - low)) / 6
					else
						hue = (4 + (r - g) / (high - low)) / 6
					end

					hue = hue - math_floor(hue)
				end
			end
		end

		local value = ffi.new("float[1]", 1000)

		if shown then
			value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
		end

		for i = 1, #SURFACE_BAKED do
			local entry = SURFACE_BAKED[i]
			local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. entry.template, "rb")
			local template = template_file and template_file:read("*a")

			if template_file then
				template_file:close()
			end

			if template and #template == entry.size then
				local bytes = string.sub(template, 1, entry.offset) .. ffi.string(value, 4) .. string.sub(template, entry.offset + 5)
				local path = SOUL_PAYLOAD_DIR .. entry.file
				local existing = lua_io.open(path, "rb")
				local current = existing and existing:read("*a")

				if existing then
					existing:close()
				end

				if current ~= bytes then
					local out = lua_io.open(path, "wb")

					if out then
						out:write(bytes)
						out:close()
					else
						mod:info("las surface glow: cannot write %s", path)
					end
				end
			end
		end
	end

	local function bake_glow_material()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			return
		end

		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. GLOW_TEMPLATE_FILE, "rb")

		if not template_file then
			mod:info("las glow colour: template missing, shipped default used")

			return
		end

		local template = template_file:read("*a")

		template_file:close()

		if not template or #template ~= GLOW_TEMPLATE_SIZE then
			return
		end

		local bytes = template

		local mode = mod:get("las_mine_mode")

		if mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow") then
			local colour = mod:get("las_mine_colour")
			local scale = (mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP) / STOCK_BRIGHTNESS_STEP
			local rgb = ffi.new("float[3]")

			for i = 1, 3 do
				local channel = mode == "rainbow" and 255 or (type(colour) == "table" and colour[i + 1] or 255)

				rgb[i - 1] = math_max(0, math_min(4, channel / 255 * scale))
			end

			bytes = string.sub(template, 1, GLOW_VALUE_OFFSET) .. ffi.string(rgb, 12) .. string.sub(template, GLOW_VALUE_OFFSET + 13)
		end

		local path = SOUL_PAYLOAD_DIR .. GLOW_MATERIAL_FILE
		local existing = lua_io.open(path, "rb")
		local current = existing and existing:read("*a")

		if existing then
			existing:close()
		end

		if current ~= bytes then
			local out = lua_io.open(path, "wb")

			if out then
				out:write(bytes)
				out:close()
			else
				mod:info("las glow colour: cannot write %s, shipped default used", path)
			end
		end
	end

	local function bake_soul_materials()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			mod:info("soulblaze colours: no file access, shipped defaults used")
			return
		end

		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. SOUL_TEMPLATE_FILE, "rb")

		if not template_file then
			mod:info("soulblaze colours: template missing, shipped defaults used")
			return
		end

		local template = template_file:read("*a")

		template_file:close()

		if not template or #template ~= SOUL_TEMPLATE_SIZE then
			return
		end

		local saturation, brightness = soul_bake_profile()
		local saturation_step = math_floor(saturation * SOUL_SATURATION_STEPS + 0.5)
		local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, brightness))
		local value = ffi.new("float[1]")

		for i = 1, #SOUL_SLOTS do
			local hue_step = math_floor((i - 1) / #SOUL_SLOTS * SOUL_HUE_STEPS)

			value[0] = 1000 + saturation_step + (hue_step * 16 + brightness_step) / 16384

			local bytes = string.sub(template, 1, SOUL_VALUE_OFFSET) .. ffi.string(value, 4) .. string.sub(template, SOUL_VALUE_OFFSET + 5)
			local path = SOUL_PAYLOAD_DIR .. soul_material_file(SOUL_SLOTS[i])
			local existing = lua_io.open(path, "rb")
			local current = existing and existing:read("*a")

			if existing then
				existing:close()
			end

			if current ~= bytes then
				local out = lua_io.open(path, "wb")

				if out then
					out:write(bytes)
					out:close()
				else
					mod:info("soulblaze colours: cannot write %s, shipped default used", path)
				end
			end
		end
	end

	local GLOW_REDIRECTS = {
		{
			stock = "data/bc/bc95c93681c9f0f7",
			file = "bc95c93681c9f0f7.livehsv",
			sha256 = "b7d689c5159cca7fb29b97ab4e968dc2c73907d091af3feb2728ba303a065984",
		},
		{
			stock = "data/zz/f0f0000000000101",
			file = "f0f0000000000101.glowpal",
			virtual = true,
		},
		{
			stock = "data/zz/f0f0000000000102",
			file = "f0f0000000000102.glowpal",
			virtual = true,
		},
		{
			stock = "6c363592a35f5599",
			file = "6c363592a35f5599.glowslot",
			sha256 = "8ab4b5e21781b700051df420a400b0f3ae028ca7d272640eb38571936f405c4f",
		},
		{
			stock = "data/zz/f0f0000000000007",
			file = "f0f0000000000007.glowpal",
			virtual = true,
		},
		{
			stock = "88cedce8a498f97e",
			file = "88cedce8a498f97e.glowslot",
			sha256 = "4dea34a5d7d323d046af778991c008e2352982a0d2b8106cf1860566d8bc0f96",
		},
		{
			stock = "data/zz/f0f0000000000008",
			file = "f0f0000000000008.glowpal",
			virtual = true,
		},
		{
			stock = "d932eac771ff85ae",
			file = "d932eac771ff85ae.glowslot",
			sha256 = "38d3c5c84bab2547f5ecd0c17d2f0658295f4ffd137b2a828a149404d58ee782",
		},
		{
			stock = "data/zz/f0f0000000000009",
			file = "f0f0000000000009.glowpal",
			virtual = true,
		},
		{
			stock = "81686d16269ea030",
			file = "81686d16269ea030.glowslot",
			sha256 = "89d512bf2f590d966944fa3cd71d3ce262f7ac8aad3b9e789f46731cd29c8cd1",
		},
		{
			stock = "data/zz/f0f000000000000a",
			file = "f0f000000000000a.glowpal",
			virtual = true,
		},
		{
			stock = "43fcfaba468316d8",
			file = "43fcfaba468316d8.glowslot",
			sha256 = "8a0c6162946fcb7e99f43ccecac541773b9ace84973ce0fea77c3d3271426e1b",
		},
		{
			stock = "data/zz/f0f000000000000b",
			file = "f0f000000000000b.glowpal",
			virtual = true,
		},
		{
			stock = "ff966c81581e8207",
			file = "ff966c81581e8207.glowslot",
			sha256 = "0146e4e7e09303bdcafaf56305ba6dcdb64328fa826432ddc64bea2520524998",
		},
		{
			stock = "data/zz/f0f000000000000c",
			file = "f0f000000000000c.glowpal",
			virtual = true,
		},
	}

	for i = 1, #GLOW_REDIRECTS do
		REDIRECTS[#REDIRECTS + 1] = GLOW_REDIRECTS[i]
	end

	for i = 1, #SOUL_SLOTS do
		local slot = SOUL_SLOTS[i]

		REDIRECTS[#REDIRECTS + 1] = { stock = slot.bundle, file = slot.bundle .. ".soulslot", sha256 = slot.bundle_sha256 }
		slot.bundle_redirect = #REDIRECTS
		REDIRECTS[#REDIRECTS + 1] = { stock = slot.material, file = soul_material_file(slot), sha256 = slot.material_sha256 }
		slot.material_redirect = #REDIRECTS
	end

	local BURN_BUNDLES = {
		{ bundle = "3d574968047de622", sha256 = "6dd0375c40c895e581ded45e0aac09a6e1c2f4a48c9dcaea993410a06a005471", package = "content/fx/particles/enemies/buff_burning" },
		{ bundle = "ec588082b617bc4d", sha256 = "cb962d2a7df373986633cff3efaa12f17b5bcbf00368c855478162d4aab45fdc", package = "content/fx/particles/enemies/buff_burning_stack_lvl02" },
		{ bundle = "a9dfcc3f7330140a", sha256 = "02ac7bca710a567d729e2f8bd133da3519bce1708b70d5b8315737fb1f217de0", package = "content/fx/particles/enemies/buff_burning_stack_lvl03" },
	}

	for i = 1, #BURN_BUNDLES do
		REDIRECTS[#REDIRECTS + 1] = { stock = BURN_BUNDLES[i].bundle, file = BURN_BUNDLES[i].bundle .. ".pyro", sha256 = BURN_BUNDLES[i].sha256 }
	end

	for layer = 1, #BURN_LAYERS do
		for slot = 1, BURN_PALETTE_SLOTS do
			REDIRECTS[#REDIRECTS + 1] = { stock = burn_material_loose(layer, slot), file = burn_material_file(layer, slot), virtual = true }
		end
	end

	REDIRECTS[#REDIRECTS + 1] = { stock = "data/zz/f0f5000000001f01", file = "3586b12003ab11fc.livehsv", virtual = true }
	REDIRECTS[#REDIRECTS + 1] = { stock = "data/zz/f0f5000000001f02", file = "5b86a311c0ac5cf0.livehsv", virtual = true }

	bake_soul_materials()

	local BURN_BAKE_SOURCES = { "flamer_mine_", "flamer_team_", "skull_mine_", "skull_team_" }

	local function burn_bake_profile()
		for _, prefix in ipairs(BURN_BAKE_SOURCES) do
			local mode = mod:get(prefix .. "mode") or "stock"

			if mod:get(prefix .. "show") ~= false and mode ~= "stock" then
				local saturation = 1
				local colour = mod:get(prefix .. "colour")

				if mode ~= "rainbow" and type(colour) == "table" then
					local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
					local high = math_max(r, g, b)

					saturation = high > 0 and (high - math_min(r, g, b)) / high or 0
				end

				return saturation, mod:get(prefix .. "brightness") or STOCK_BRIGHTNESS_STEP
			end
		end

		return 1, STOCK_BRIGHTNESS_STEP
	end

	local function bake_burn_materials()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			mod:info("burn colours: no file access, shipped defaults used")
			return
		end

		local saturation, brightness = burn_bake_profile()
		local saturation_step = math_floor(saturation * SOUL_SATURATION_STEPS + 0.5)
		local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, brightness))
		local value = ffi.new("float[1]")

		for layer = 1, #BURN_LAYERS do
			local spec = BURN_LAYERS[layer]
			local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. spec.template, "rb")
			local template = template_file and template_file:read("*a")

			if template_file then
				template_file:close()
			end

			if template and #template == spec.size then
				for slot = 1, BURN_PALETTE_SLOTS do
					local hue_step = math_floor((slot - 1) / BURN_PALETTE_SLOTS * SOUL_HUE_STEPS)

					value[0] = 1000 + saturation_step + (hue_step * 16 + brightness_step) / 16384

					local bytes = string.sub(template, 1, spec.offset) .. ffi.string(value, 4) .. string.sub(template, spec.offset + 5)
					local path = SOUL_PAYLOAD_DIR .. burn_material_file(layer, slot)
					local existing = lua_io.open(path, "rb")
					local current = existing and existing:read("*a")

					if existing then
						existing:close()
					end

					if current ~= bytes then
						local out = lua_io.open(path, "wb")

						if out then
							out:write(bytes)
							out:close()
						else
							mod:info("burn colours: cannot write %s", path)
						end
					end
				end
			else
				mod:info("burn colours: template %s missing or wrong size", spec.template)
			end
		end
	end

	bake_burn_materials()
	local PLASMA_TRAIL_TEMPLATE = "c9a22ea5418d46c4.plasmatemplate"
	local PLASMA_TRAIL_SIZE = 116416
	local PLASMA_TRAIL_OFFSET = 328
	local PLASMA_TRAIL_SLOTS = {
		{ file = "f0f0000000000901.plasmapal", name = "\31\215\71\224\127\72\39\252" },
		{ file = "f0f0000000000902.plasmapal", name = "\168\247\196\175\120\157\17\12" },
		{ file = "f0f0000000000903.plasmapal", name = "\86\31\230\40\154\61\162\12" },
		{ file = "f0f0000000000904.plasmapal", name = "\165\117\61\166\95\205\86\197" },
		{ file = "f0f0000000000905.plasmapal", name = "\110\237\38\56\188\247\87\223" },
		{ file = "f0f0000000000906.plasmapal", name = "\38\87\66\155\225\146\109\126" },
		{ file = "f0f0000000000907.plasmapal", name = "\53\216\93\40\180\129\196\174" },
		{ file = "f0f0000000000908.plasmapal", name = "\237\106\184\213\197\127\188\31" },
		{ file = "f0f0000000000909.plasmapal", name = "\232\168\238\210\232\12\248\55" },
		{ file = "f0f000000000090a.plasmapal", name = "\156\39\211\204\138\223\81\164" },
		{ file = "f0f000000000090b.plasmapal", name = "\182\0\199\225\63\100\113\86" },
		{ file = "f0f000000000090c.plasmapal", name = "\133\11\188\236\167\89\31\188" },
	}

	local function bake_plasma_trail()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io

		if not ffi or not lua_io then
			return
		end

		local template_file = lua_io.open(SOUL_PAYLOAD_DIR .. PLASMA_TRAIL_TEMPLATE, "rb")
		local template = template_file and template_file:read("*a")

		if template_file then
			template_file:close()
		end

		if not template or #template ~= PLASMA_TRAIL_SIZE then
			mod:info("plasma trail palette: template missing or wrong size")

			return
		end

		local mode = mod:get("plasma_mine_mode")
		local shown = mod:get("plasma_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
		local brightness = math_max(1, math_min(15, mod:get("plasma_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local saturation_step = 15

		if mode == "custom" then
			local colour = mod:get("plasma_mine_colour")

			if type(colour) == "table" then
				local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
				local high, low = math_max(r, g, b), math_min(r, g, b)

				saturation_step = math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)
			end
		end

		for i = 1, #PLASMA_TRAIL_SLOTS do
			local slot = PLASMA_TRAIL_SLOTS[i]
			local bytes = template

			if shown then
				local value = ffi.new("float[1]")
				local hue = (i - 1) / #PLASMA_TRAIL_SLOTS

				value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
				bytes = string.sub(template, 1, PLASMA_TRAIL_OFFSET) .. ffi.string(value, 4) .. string.sub(template, PLASMA_TRAIL_OFFSET + 5)
			end

			local path = SOUL_PAYLOAD_DIR .. slot.file
			local existing = lua_io.open(path, "rb")
			local current = existing and existing:read("*a")

			if existing then
				existing:close()
			end

			if current ~= bytes then
				local out = lua_io.open(path, "wb")

				if out then
					out:write(bytes)
					out:close()
				else
					mod:info("plasma trail palette: cannot write %s", path)
				end
			end
		end
	end
	bake_glow_material()
	bake_glow_palette()
	bake_surface_glow()
	bake_impact_glow()
	bake_plasma_trail()

	return {
		payload_dir = SOUL_PAYLOAD_DIR,
		glow_slots = GLOW_SLOTS,
		glow_source_effects = GLOW_SOURCE_EFFECTS,
	}
end
