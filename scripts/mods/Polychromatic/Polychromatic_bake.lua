return function(context)
	local mod = context.mod
	local module_data = context.data
	local bake_module = context.bake_module
	local detail = context.detail
	local math_floor = math.floor
	local math_max = math.max
	local math_min = math.min
	local string_sub = string.sub
	local string_byte = string.byte
	local REDIRECTS = context.redirects
	local SOUL_SLOTS = context.soul_slots
	local MIN_BRIGHTNESS_STEP = context.min_brightness
	local STOCK_BRIGHTNESS_STEP = context.stock_brightness
	local MAX_BRIGHTNESS_STEP = context.max_brightness
	local STAMP_SETTING = "bake_stamp"

	local SOUL_MODULE = bake_module("soul")
	local BURN_MODULE = bake_module("burn")
	local GLOW_MODULE = bake_module("glow")
	local PLASMA_MODULE = bake_module("plasma")
	local PAYLOAD_ROOT = "../mods/" .. (mod:get_internal_data("load_order_name") or mod:get_name()) .. "/modules/"

	local function payload_dir(module_id)
		return module_id and PAYLOAD_ROOT .. module_id .. "/payload/"
	end

	local SOUL_PAYLOAD_DIR = payload_dir(SOUL_MODULE)
	local BURN_PAYLOAD_DIR = payload_dir(BURN_MODULE)
	local GLOW_PAYLOAD_DIR = payload_dir(GLOW_MODULE)
	local PLASMA_PAYLOAD_DIR = payload_dir(PLASMA_MODULE)
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
		return string_sub(slot.material, 9) .. ".soulmat"
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

	local GLOW_SLOTS = module_data("glow_slots")

	local GLOW_SOURCE_EFFECTS = {
		["content/fx/particles/weapons/rifles/laspistol/laspistol_heavy_muzzle"] = "muzzle",
	}
	local GLOW_IMPACT_TEMPLATE = "7082301abe176951.impactglowtemplate"
	local GLOW_MUZZLE_TEMPLATE = "0937ecdd02b49a51.glowtemplate"
	local GLOW_IMPACT_SIZE, GLOW_IMPACT_OFFSET = 374957, 244
	local GLOW_MUZZLE_SIZE, GLOW_MUZZLE_OFFSET = 308, 264

	local SURFACE_BAKED = {
		{ template = "f0f0000000000101.surftemplate", file = "f0f0000000000101.glowpal", size = 393660, offset = 244 },
		{ template = "f0f0000000000102.surftemplate", file = "f0f0000000000102.glowpal", size = 374989, offset = 244 },
	}

	local BURN_BAKE_SOURCES = { "flamer_mine_", "flamer_team_", "skull_mine_", "skull_team_" }

	local PLASMA_TRAIL_TEMPLATE = "c9a22ea5418d46c4.plasmatemplate"
	local PLASMA_TRAIL_SIZE = 116416
	local PLASMA_TRAIL_OFFSET = 328
	local PLASMA_TRAIL_SLOTS = module_data("plasma_trail_slots")

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

	local function las_hue_saturation()
		local hue, saturation = 0, 0
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

		return hue, saturation
	end

	local function saturation_step_of(prefix)
		local colour = mod:get(prefix .. "colour")

		if type(colour) == "table" then
			local r, g, b = (colour[2] or 0) / 255, (colour[3] or 0) / 255, (colour[4] or 0) / 255
			local high, low = math_max(r, g, b), math_min(r, g, b)

			return math_floor((high > 0 and (high - low) / high or 0) * 15 + 0.5)
		end

		return nil
	end

	-- Plan functions

	local function plan_soul(ffi, groups)
		local saturation, brightness = soul_bake_profile()
		local saturation_step = math_floor(saturation * SOUL_SATURATION_STEPS + 0.5)
		local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, brightness))
		local value = ffi.new("float[1]")
		local jobs = {}

		for i = 1, #SOUL_SLOTS do
			local hue_step = math_floor((i - 1) / #SOUL_SLOTS * SOUL_HUE_STEPS)

			value[0] = 1000 + saturation_step + (hue_step * 16 + brightness_step) / 16384
			jobs[#jobs + 1] = { path = SOUL_PAYLOAD_DIR .. soul_material_file(SOUL_SLOTS[i]), offset = SOUL_VALUE_OFFSET, patch = ffi.string(value, 4), fail = "soulblaze colours: cannot write %s, shipped default used" }
		end

		groups[#groups + 1] = { template = SOUL_PAYLOAD_DIR .. SOUL_TEMPLATE_FILE, size = SOUL_TEMPLATE_SIZE, missing = "soulblaze colours: template missing, shipped defaults used", jobs = jobs }
	end

	local function plan_burn(ffi, groups)
		local saturation, brightness = burn_bake_profile()
		local saturation_step = math_floor(saturation * SOUL_SATURATION_STEPS + 0.5)
		local brightness_step = math_max(MIN_BRIGHTNESS_STEP, math_min(MAX_BRIGHTNESS_STEP, brightness))
		local value = ffi.new("float[1]")

		for layer = 1, #BURN_LAYERS do
			local spec = BURN_LAYERS[layer]
			local jobs = {}
			local message = "burn colours: template " .. spec.template .. " missing or wrong size"

			for slot = 1, BURN_PALETTE_SLOTS do
				local hue_step = math_floor((slot - 1) / BURN_PALETTE_SLOTS * SOUL_HUE_STEPS)

				value[0] = 1000 + saturation_step + (hue_step * 16 + brightness_step) / 16384
				jobs[#jobs + 1] = { path = BURN_PAYLOAD_DIR .. burn_material_file(layer, slot), offset = spec.offset, patch = ffi.string(value, 4), fail = "burn colours: cannot write %s" }
			end

			groups[#groups + 1] = { template = BURN_PAYLOAD_DIR .. spec.template, size = spec.size, missing = message, wrong = message, jobs = jobs }
		end
	end

	local function plan_glow_material(ffi, groups)
		local patch = nil
		local mode = mod:get("las_mine_mode")

		if mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow") then
			local colour = mod:get("las_mine_colour")
			local scale = (mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP) / STOCK_BRIGHTNESS_STEP
			local rgb = ffi.new("float[3]")

			for i = 1, 3 do
				local channel = mode == "rainbow" and 255 or (type(colour) == "table" and colour[i + 1] or 255)

				rgb[i - 1] = math_max(0, math_min(4, channel / 255 * scale))
			end

			patch = ffi.string(rgb, 12)
		end

		groups[#groups + 1] = {
			template = GLOW_PAYLOAD_DIR .. GLOW_TEMPLATE_FILE,
			size = GLOW_TEMPLATE_SIZE,
			missing = "las glow colour: template missing, shipped default used",
			jobs = { { path = GLOW_PAYLOAD_DIR .. GLOW_MATERIAL_FILE, offset = GLOW_VALUE_OFFSET, patch = patch, fail = "las glow colour: cannot write %s, shipped default used" } },
		}
	end

	local function plan_glow_palette(ffi, groups)
		local mode = mod:get("las_mine_mode")
		local shown = mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
		local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local saturation_step = 15

		if mode == "custom" then
			saturation_step = saturation_step_of("las_mine_") or saturation_step
		end

		for layer, list in pairs(GLOW_SLOTS) do
			local template_name = layer == "impact" and GLOW_IMPACT_TEMPLATE or GLOW_MUZZLE_TEMPLATE
			local size = layer == "impact" and GLOW_IMPACT_SIZE or GLOW_MUZZLE_SIZE
			local offset = layer == "impact" and GLOW_IMPACT_OFFSET or GLOW_MUZZLE_OFFSET
			local jobs = {}

			for i = 1, #list do
				local hue = glow_hue_of(list, i)
				local patch = nil

				if shown and layer == "impact" then
					local value = ffi.new("float[1]")

					value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
					patch = ffi.string(value, 4)
				elseif shown then
					local r, g, b = glow_hsv_rgb(hue, saturation_step / 15, brightness / STOCK_BRIGHTNESS_STEP)
					local rgb = ffi.new("float[3]", r, g, b)

					patch = ffi.string(rgb, 12)
				end

				jobs[#jobs + 1] = { path = GLOW_PAYLOAD_DIR .. list[i].material .. ".glowpal", offset = offset, patch = patch, fail = "las glow palette: cannot write %s" }
			end

			groups[#groups + 1] = { template = GLOW_PAYLOAD_DIR .. template_name, size = size, jobs = jobs }
		end
	end

	local function plan_surface_glow(ffi, groups)
		local mode = mod:get("las_mine_mode")
		local shown = mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
		local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local hue, saturation_step = 0, 0

		if mode == "custom" then
			local saturation

			hue, saturation = las_hue_saturation()
			saturation_step = type(mod:get("las_mine_colour")) == "table" and math_floor(saturation * 15 + 0.5) or 0
		end

		local value = ffi.new("float[1]", 1000)

		if shown then
			value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
		end

		local patch = ffi.string(value, 4)

		for i = 1, #SURFACE_BAKED do
			local entry = SURFACE_BAKED[i]

			groups[#groups + 1] = {
				template = GLOW_PAYLOAD_DIR .. entry.template,
				size = entry.size,
				jobs = { { path = GLOW_PAYLOAD_DIR .. entry.file, offset = entry.offset, patch = patch, fail = "las surface glow: cannot write %s" } },
			}
		end
	end

	local function plan_impact_glow(ffi, groups)
		local value = ffi.new("float[1]", 1000)
		local mode = mod:get("las_mine_mode")

		if mod:get("las_mine_show") ~= false and (mode == "custom" or mode == "rainbow") then
			local brightness = math_max(1, math_min(15, mod:get("las_mine_brightness") or STOCK_BRIGHTNESS_STEP))
			local hue, saturation = 0, 0

			if mode == "custom" then
				hue, saturation = las_hue_saturation()
			end

			local hue_step = math_floor(hue * 1024) % 1024
			local saturation_step = math_floor(saturation * 15 + 0.5)

			value[0] = 1000 + saturation_step + (hue_step * 16 + brightness) / 16384
		end

		groups[#groups + 1] = {
			template = GLOW_PAYLOAD_DIR .. IMPACT_GLOW_TEMPLATE_FILE,
			size = IMPACT_GLOW_SIZE,
			missing = "las impact glow: template missing, shipped default used",
			jobs = { { path = GLOW_PAYLOAD_DIR .. IMPACT_GLOW_FILE, offset = IMPACT_GLOW_OFFSET, patch = ffi.string(value, 4), fail = "las impact glow: cannot write %s, shipped default used" } },
		}
	end

	local function plan_plasma_trail(ffi, groups)
		local mode = mod:get("plasma_mine_mode")
		local shown = mod:get("plasma_mine_show") ~= false and (mode == "custom" or mode == "rainbow")
		local brightness = math_max(1, math_min(15, mod:get("plasma_mine_brightness") or STOCK_BRIGHTNESS_STEP))
		local saturation_step = 15
		local jobs = {}

		if mode == "custom" then
			saturation_step = saturation_step_of("plasma_mine_") or saturation_step
		end

		for i = 1, #PLASMA_TRAIL_SLOTS do
			local patch = nil

			if shown then
				local value = ffi.new("float[1]")
				local hue = (i - 1) / #PLASMA_TRAIL_SLOTS

				value[0] = 1000 + saturation_step + (math_floor(hue * 1024) % 1024 * 16 + brightness) / 16384
				patch = ffi.string(value, 4)
			end

			jobs[#jobs + 1] = { path = PLASMA_PAYLOAD_DIR .. PLASMA_TRAIL_SLOTS[i].file, offset = PLASMA_TRAIL_OFFSET, patch = patch, fail = "plasma trail palette: cannot write %s" }
		end

		local message = "plasma trail palette: template missing or wrong size"

		groups[#groups + 1] = { template = PLASMA_PAYLOAD_DIR .. PLASMA_TRAIL_TEMPLATE, size = PLASMA_TRAIL_SIZE, missing = message, wrong = message, jobs = jobs }
	end

	-- Stamp functions

	local bit = rawget(_G, "bit") or require("bit")
	local bit_bxor = bit.bxor
	local bit_lshift = bit.lshift
	local bit_tobit = bit.tobit
	local bit_tohex = bit.tohex

	local function digest(text)
		local h1, h2 = bit_tobit(2166136261), 5381
		local length = #text

		for i = 1, length do
			local c = string_byte(text, i)

			h1 = bit_bxor(h1, c)
			h1 = bit_tobit(bit_lshift(h1, 24) + h1 * 403)
			h2 = bit_tobit(h2 * 33 + c)
		end

		return length .. ":" .. bit_tohex(h1) .. bit_tohex(h2)
	end

	local function stamp_of(stat, groups)
		if not stat then
			return nil
		end

		local parts = {}

		for g = 1, #groups do
			local group = groups[g]
			local size, written = stat(group.template)

			if size ~= group.size then
				return nil
			end

			parts[#parts + 1] = group.template .. "|" .. written

			for j = 1, #group.jobs do
				local job = group.jobs[j]
				local out_size, out_written = stat(job.path)

				if not out_size then
					return nil
				end

				parts[#parts + 1] = job.path .. "|" .. out_size .. "|" .. out_written .. "|" .. (job.patch and (#job.patch .. ":" .. job.patch) or "-")
			end
		end

		return digest(table.concat(parts, "\n"))
	end

	-- Bake functions

	local function bake_groups(lua_io, groups, counts)
		local templates = {}

		for g = 1, #groups do
			local group = groups[g]
			local template = templates[group.template]

			if template == nil then
				local file = lua_io.open(group.template, "rb")

				counts.opens = counts.opens + 1
				template = false

				if file then
					template = file:read("*a") or true
					file:close()
				end

				templates[group.template] = template
			end

			if template == false then
				counts.problems = counts.problems + 1

				if group.missing then
					mod:info("%s", group.missing)
				end
			elseif template == true or #template ~= group.size then
				counts.problems = counts.problems + 1

				if group.wrong then
					mod:info("%s", group.wrong)
				end
			else
				for j = 1, #group.jobs do
					local job = group.jobs[j]
					local patch = job.patch
					local bytes = template

					if patch then
						bytes = string_sub(template, 1, job.offset) .. patch .. string_sub(template, job.offset + #patch + 1)
					end

					local existing = lua_io.open(job.path, "rb")
					local current = existing and existing:read("*a")

					counts.opens = counts.opens + 1

					if existing then
						existing:close()
					end

					if current ~= bytes then
						local out = lua_io.open(job.path, "wb")

						counts.opens = counts.opens + 1

						if out then
							out:write(bytes)
							out:close()
							counts.writes = counts.writes + 1
						else
							counts.problems = counts.problems + 1
							mod:info(job.fail, job.path)
						end
					end
				end
			end
		end
	end

	local function lap(name)
		if detail then
			detail.lap("bake", name)
		end
	end

	local function bake()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local lua_io = lua and lua.io
		local counts = { opens = 0, writes = 0, problems = 0, skipped = 0 }

		if not ffi or not lua_io then
			if SOUL_MODULE then
				mod:info("soulblaze colours: no file access, shipped defaults used")
			end

			if BURN_MODULE then
				mod:info("burn colours: no file access, shipped defaults used")
			end

			return counts
		end

		local groups = {}

		if SOUL_MODULE then
			plan_soul(ffi, groups)
		end

		if BURN_MODULE then
			plan_burn(ffi, groups)
		end

		if GLOW_MODULE then
			plan_glow_material(ffi, groups)
			plan_glow_palette(ffi, groups)
			plan_surface_glow(ffi, groups)
			plan_impact_glow(ffi, groups)
		end

		if PLASMA_MODULE then
			plan_plasma_trail(ffi, groups)
		end

		lap("plan")

		local stat_module = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/file_stat")
		local stat = type(stat_module) == "table" and stat_module.stat or nil
		local before = stamp_of(stat, groups)

		lap("stamp")

		if before and before == mod:get(STAMP_SETTING) then
			counts.skipped = 1
			lap("io")

			return counts
		end

		bake_groups(lua_io, groups, counts)

		local after = counts.problems == 0 and stamp_of(stat, groups) or nil

		if after ~= mod:get(STAMP_SETTING) then
			mod:set(STAMP_SETTING, after)
		end

		lap("io")

		return counts
	end

	if SOUL_MODULE then
		for i = 1, #SOUL_SLOTS do
			local slot = SOUL_SLOTS[i]

			REDIRECTS[#REDIRECTS + 1] = { stock = string.format("data/zz/f0f50000000030%02x", i - 1), file = soul_material_file(slot), virtual = true, module = SOUL_MODULE }
			slot.material_redirect = #REDIRECTS
		end
	end

	if BURN_MODULE then
		for layer = 1, #BURN_LAYERS do
			for slot = 1, BURN_PALETTE_SLOTS do
				REDIRECTS[#REDIRECTS + 1] = { stock = burn_material_loose(layer, slot), file = burn_material_file(layer, slot), virtual = true, module = BURN_MODULE }
			end
		end
	end

	if GLOW_MODULE then
		REDIRECTS[#REDIRECTS + 1] = { stock = "data/zz/f0f5000000003100", file = GLOW_MATERIAL_FILE, virtual = true, module = GLOW_MODULE }
		REDIRECTS[#REDIRECTS + 1] = { stock = "data/zz/f0f5000000003101", file = IMPACT_GLOW_FILE, virtual = true, module = GLOW_MODULE }
	end

	lap("load")

	local counts = bake()

	if detail then
		detail.count("bake", "skipped", counts.skipped)
		detail.count("bake", "opens", counts.opens)
		detail.count("bake", "writes", counts.writes)
	end

	return {
		glow_slots = GLOW_SLOTS,
		glow_source_effects = GLOW_SOURCE_EFFECTS,
	}
end
