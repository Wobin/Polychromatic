return function(mod, core, data_list)
	local SETTINGS = {
		{ setting = "terrain_tesselation_min_distance", stock = "5" },
		{ setting = "terrain_tesselation_max_distance", stock = "50" },
		{ setting = "terrain_displacement_min_distance", stock = "30" },
		{ setting = "terrain_displacement_max_distance", stock = "40" },
		{ setting = "hdr_paper_white_nits", stock = "400" },
		{ setting = "rt_shadow_ray_multiplier", stock = "2" },
	}
	local SLOTS_PER_SETTING = 3
	local SLOTS = mod:io_dofile("Polychromatic/channels")

	if type(SLOTS) ~= "table" then
		error("channels.lua did not load", 0)
	end

	local CHANNELS = {}
	local by_setting = {}

	for i = 1, #SETTINGS do
		local entry = SETTINGS[i]
		local channel = { setting = entry.setting, stock = entry.stock, slots = {} }

		CHANNELS[i] = channel
		by_setting[entry.setting] = channel
	end

	for i = 1, #SLOTS do
		local entry = SLOTS[i]
		local channel = by_setting[entry.setting]
		local set, owner = string.match(tostring(entry.name), "^(.+)_([a-z]+)$")

		if channel and set and type(entry.slot) == "number" and entry.slot >= 1 and entry.slot <= SLOTS_PER_SETTING then
			channel.slots[entry.slot] = { set = set, owner = owner }
		end
	end

	local CHECK_INTERVAL = 0.5
	local SETTINGS_EVENT = "event_on_render_settings_applied"
	local MANTISSA = 8388608

	local math_floor = math.floor
	local math_max = math.max
	local math_min = math.min
	local string_format = string.format
	local set_render_setting = Application.set_render_setting

	local _t = CHECK_INTERVAL
	local _attached = nil
	local _written = {}
	local channels = {}

	local function slot_code(slot, t)
		if not slot then
			return 0, false
		end

		local profile = core.profile_for(slot.set, slot.owner)
		local mode = profile and profile.mode

		if mode ~= "custom" and mode ~= "rainbow" then
			return 0, false
		end

		local hue = profile.hue or 0
		local saturation = profile.saturation or 1

		if mode == "rainbow" then
			local phase = t * core.RAINBOW_CYCLES_PER_SECOND

			hue = phase - math_floor(phase)
			saturation = 1
		end

		local hq = math_floor(hue * 32 + 0.5) % 32
		local sq = math_max(0, math_min(3, math_floor(saturation * 3 + 0.5)))
		local factor = (profile.brightness or core.STOCK_BRIGHTNESS_STEP) / core.STOCK_BRIGHTNESS_STEP
		local vq = math_max(0, math_min(3, math_floor(factor * 2 - 1 + 0.5)))

		return hq * 16 + sq * 4 + vq, true
	end

	local function value_for(channel, t)
		local packed, any = 0, false
		local scale = 1

		for i = 1, SLOTS_PER_SETTING do
			local code, on = slot_code(channel.slots[i], t)

			packed = packed + code * scale
			scale = scale * 512
			any = any or on
		end

		if not any then
			return channel.stock
		end

		local k = math_floor(packed / MANTISSA)
		local m = packed - k * MANTISSA

		return string_format("%.10f", (2 ^ (13 + k)) * (1 + m / MANTISSA))
	end

	function channels.write(force)
		local t = core.gameplay_time()

		for i = 1, #CHANNELS do
			local channel = CHANNELS[i]
			local value = value_for(channel, t)

			if next(channel.slots) ~= nil and (force or _written[channel.setting] ~= value) then
				set_render_setting(channel.setting, value)
				_written[channel.setting] = value
			end
		end
	end

	local listener = {}

	listener[SETTINGS_EVENT] = function()
		channels.write(true)
	end

	function channels.attach()
		local events = Managers and Managers.event

		if events and _attached ~= events then
			events:register(listener, SETTINGS_EVENT, SETTINGS_EVENT)
			_attached = events
		end
	end

	function channels.detach()
		if _attached and not rawget(_attached, "__deleted") then
			_attached:unregister(listener, SETTINGS_EVENT)
		end

		_attached = nil
	end

	function channels.update(dt)
		_t = _t + dt

		if _t < CHECK_INTERVAL then
			return
		end

		_t = 0
		channels.attach()
		channels.write(false)
	end

	function channels.restore(force)
		for i = 1, #CHANNELS do
			local channel = CHANNELS[i]

			if force or next(channel.slots) ~= nil or _written[channel.setting] ~= nil then
				set_render_setting(channel.setting, channel.stock)
			end

			_written[channel.setting] = nil
		end
	end

	function channels.report()
		local lines = {}

		for i = 1, #CHANNELS do
			local channel = CHANNELS[i]
			local names = {}

			for k = 1, SLOTS_PER_SETTING do
				local slot = channel.slots[k]

				if slot then
					names[#names + 1] = slot.set .. " " .. slot.owner
				end
			end

			lines[i] = string.format("%s: live (%s)", channel.setting, table.concat(names, ", "))
		end

		return lines
	end

	return channels
end
