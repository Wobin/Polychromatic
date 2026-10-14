return function(mod, core, data_list)
	local LIGHT_UNIT = "content/environment/light"
	local FULL_SPECTRUM_CCT = 12000
	local POOL_LIMIT = 16
	local INTENSITY_SCALE = 20
	local SPOT_START = 30 / 180 * math.pi
	local SPOT_END = 80 / 180 * math.pi

	local STAGES = {}
	local STREAMS = {}

	for _, data in ipairs(data_list) do
		for target, part in pairs({ [STAGES] = data.stages, [STREAMS] = data.streams }) do
			for key, value in pairs(part) do
				if target[key] == nil then
					target[key] = value
				end
			end
		end
	end

	local STREAM_STAGES = {
		{ at = 0, luminance = 10, falloff = 1.5 },
		{ at = 0.5, luminance = 101, falloff = 4 },
	}
	local STREAM_SCALE = 0.1
	local STREAM_LINGER = 0.2

	local math_floor = math.floor
	local math_max = math.max
	local math_min = math.min
	local Unit_alive = Unit.alive

	local _copies = nil
	local _pool = {}
	local _live = {}
	local _streams = {}
	local lights = {}

	local function copies()
		if _copies then
			return _copies
		end

		_copies = {}

		for stock, entry in pairs(core.palettes) do
			if STAGES[stock] then
				for owner, owned in pairs(entry.owners) do
					for i = 1, #owned.names do
						_copies[owned.names[i]] = { stock = stock, set = entry.set, owner = owner }
					end
				end
			end
		end

		return _copies
	end

	local function sample(xs, ys, t)
		if t <= xs[1] then
			return ys[1]
		end

		for i = 2, #xs do
			if t <= xs[i] then
				local span = xs[i] - xs[i - 1]
				local k = span > 0 and (t - xs[i - 1]) / span or 1

				return ys[i - 1] + (ys[i] - ys[i - 1]) * k
			end
		end

		return ys[#ys]
	end

	local function colour_for(set_id, owner, t)
		local profile = core.profile_for(set_id, owner)
		local mode = profile and profile.mode

		if mode ~= "custom" and mode ~= "rainbow" then
			return nil
		end

		local hue = profile.hue or 0
		local saturation = profile.saturation or 1

		if mode == "rainbow" then
			local phase = t * core.RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
			saturation = 1
		end

		local brightness = (profile.brightness or core.STOCK_BRIGHTNESS_STEP) / core.STOCK_BRIGHTNESS_STEP
		local r, g, b = core.hsv_to_rgb(hue, saturation, 1)

		return r, g, b, brightness
	end

	local function hide_meshes(unit)
		for i = 1, Unit.num_meshes(unit) do
			Unit.set_mesh_visibility(unit, i, false)
		end
	end

	local function acquire(world)
		local entry = table.remove(_pool)

		while entry and not (Unit_alive(entry.unit) and entry.world == world) do
			entry = table.remove(_pool)
		end

		if entry then
			return entry
		end

		if #_live >= POOL_LIMIT then
			for i = 1, #_live do
				if _live[i].world == world then
					entry = table.remove(_live, i)
					entry.done = true

					return entry
				end
			end

			return nil
		end

		if not Application.can_get_resource("unit", LIGHT_UNIT) then
			return nil
		end

		local unit = World.spawn_unit_ex(world, LIGHT_UNIT, nil, Vector3(0, 0, -1000), Quaternion.look(Vector3(0, 0, -1), Vector3(0, 1, 0)))
		local light = unit and Unit.light(unit, 1)

		if not light then
			if unit then
				World.destroy_unit(world, unit)
			end

			return nil
		end

		hide_meshes(unit)
		Light.set_correlated_color_temperature(light, FULL_SPECTRUM_CCT)
		Light.set_spot_reflector(light, true)
		Light.set_spot_angle_start(light, SPOT_START)
		Light.set_spot_angle_end(light, SPOT_END)

		return { unit = unit, light = light, world = world }
	end

	local function release(entry)
		if Unit_alive(entry.unit) then
			Light.set_intensity(entry.light, 0)
			Light.set_enabled(entry.light, false)
			_pool[#_pool + 1] = entry
		end
	end

	local function set_colour(entry, r, g, b)
		local light = entry.light

		Light.set_color_filter(light, Vector3(1, 1, 1))

		local base = Light.color(light)
		local fx = base.x > 0.0001 and r / base.x or 0
		local fy = base.y > 0.0001 and g / base.y or 0
		local fz = base.z > 0.0001 and b / base.z or 0
		local top = math_max(fx, fy, fz)

		if top > 0 then
			fx, fy, fz = fx / top, fy / top, fz / top
		end

		Light.set_color_filter(light, Vector3(fx, fy, fz))
	end

	local function stream_colour(set_id, owner, t)
		local profile = core.profile_for(set_id, owner)
		local mode = profile and profile.mode

		if mode == "hidden" then
			return nil
		end

		if profile and profile.show and (mode == "custom" or mode == "rainbow") then
			return colour_for(set_id, owner, t)
		end

		local rgb = STREAMS[set_id]

		return rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1
	end

	local function drop_stream(key)
		local stream = _streams[key]

		_streams[key] = nil

		for _, entry in pairs(stream.entries) do
			if not entry.done then
				release(entry)
			end
		end
	end

	function lights.stream(key, world, from_pos, to_pos, set_id, owner)
		if not STREAMS[set_id] or not world then
			return
		end

		local t = core.gameplay_time()
		local r, g, b, brightness = stream_colour(set_id, owner, t)
		local stream = _streams[key]

		if not r then
			if stream then
				drop_stream(key)
			end

			return
		end

		if not stream then
			stream = { entries = {} }
			_streams[key] = stream
		end

		stream.seen = t

		for i, stage in ipairs(STREAM_STAGES) do
			local entry = stream.entries[i]

			if not entry or entry.done or entry.world ~= world or not Unit_alive(entry.unit) then
				entry = acquire(world)

				if not entry then
					return
				end

				entry.done = false
				entry.stage = nil
				entry.copy = nil
				Light.set_enabled(entry.light, true)
				stream.entries[i] = entry
			end

			Unit.set_local_position(entry.unit, 1, Vector3.lerp(from_pos, to_pos, stage.at))
			Light.set_falloff_end(entry.light, stage.falloff)
			set_colour(entry, r, g, b)
			Light.set_intensity(entry.light, stage.luminance * brightness * INTENSITY_SCALE * STREAM_SCALE)
			World.update_unit(world, entry.unit)
		end
	end

	function lights.on_spawn(world, spawn_name, position)
		local copy = copies()[spawn_name]

		if not copy or not position or not world then
			return
		end

		if Vector3.length(position) < 0.001 then
			return
		end

		local t = core.gameplay_time()
		local owner = copy.owner

		if owner == "any" or owner == "hue" then
			owner = lights.spawn_owner or "enemy"
		end

		local set_id = core.resolve_set(copy.set, copy.stock)
		local r, g, b, brightness = colour_for(set_id, owner, t)

		if not r then
			return
		end

		for _, stage in ipairs(STAGES[copy.stock]) do
			local entry = acquire(world)

			if not entry then
				return
			end

			local unit = entry.unit

			Unit.set_local_position(unit, 1, position + Vector3(0, 0, stage.height))
			Light.set_enabled(entry.light, true)
			Light.set_falloff_end(entry.light, stage.falloff)
			set_colour(entry, r, g, b)
			World.update_unit(world, unit)

			entry.stage = stage
			entry.start = t
			entry.base = stage.luminance * brightness * INTENSITY_SCALE
			entry.copy = copy
			entry.set = set_id
			entry.owner = owner
			entry.done = false
			Light.set_intensity(entry.light, 0)
			_live[#_live + 1] = entry
		end
	end

	function lights.update()
		local t = core.gameplay_time()

		for key, stream in pairs(_streams) do
			if t - stream.seen > STREAM_LINGER then
				drop_stream(key)
			end
		end

		if not _live[1] then
			return
		end
		local i = 1

		while i <= #_live do
			local entry = _live[i]
			local stage = entry.stage
			local k = (t - entry.start) / stage.life

			if entry.done or k >= 1 or k < 0 or not Unit_alive(entry.unit) then
				table.remove(_live, i)
				release(entry)
			else
				local level = sample(stage.x, stage.level, k)

				if stage.flicker then
					level = level * sample(stage.flicker_x, stage.flicker, k)
				end

				Light.set_intensity(entry.light, entry.base * level)

				if entry.copy then
					local profile = core.profile_for(entry.set, entry.owner)

					if profile and profile.mode == "rainbow" then
						local r, g, b = colour_for(entry.set, entry.owner, t)

						if r then
							set_colour(entry, r, g, b)
						end
					end
				end

				i = i + 1
			end
		end
	end

	function lights.clear()
		for key, stream in pairs(_streams) do
			_streams[key] = nil

			for _, entry in pairs(stream.entries) do
				if not entry.done and Unit_alive(entry.unit) then
					World.destroy_unit(entry.world, entry.unit)
				end
			end
		end

		for _, list in ipairs({ _live, _pool }) do
			for i = #list, 1, -1 do
				local entry = list[i]

				if Unit_alive(entry.unit) then
					World.destroy_unit(entry.world, entry.unit)
				end

				list[i] = nil
			end
		end
	end

	function lights.invalidate()
		_copies = nil
	end

	return lights
end
