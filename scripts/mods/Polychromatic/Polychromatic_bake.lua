return function(context)
	local mod = context.mod
	local REDIRECT_DATA = context.redirect_data
	local EFFECT_DATA = context.effect_data
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

	local GLOW_SLOTS = mod:io_dofile(REDIRECT_DATA .. "glow_slots")

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

	local GLOW_REDIRECTS = mod:io_dofile(REDIRECT_DATA .. "glow_redirects")

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

	local BURN_BUNDLES = mod:io_dofile(REDIRECT_DATA .. "burn_bundles")

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
	local PLASMA_TRAIL_SLOTS = mod:io_dofile(EFFECT_DATA .. "plasma_trail_slots")

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
