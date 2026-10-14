return function(mod, core, data_list)
	local BLASTS = {}
	local POOL_EFFECTS = {}
	local PLAYER_TEMPLATES = {}

	for _, data in ipairs(data_list) do
		for target, part in pairs({ [BLASTS] = data.blasts, [POOL_EFFECTS] = data.effects, [PLAYER_TEMPLATES] = data.templates }) do
			for key, value in pairs(part) do
				if target[key] == nil then
					target[key] = value
				end
			end
		end
	end

	local WINDOW = 4
	local RADIUS = 8
	local MAX_BLASTS = 8

	local _blasts = {}
	local _context = nil
	local _server_contexts = {}
	local _husk_contexts = {}
	local pools = {}

	local function call_in_context(context, func, ...)
		local previous = _context

		_context = context

		local ok, a, b = xpcall(func, core.with_traceback, ...)

		_context = previous

		if not ok then
			error(a, 0)
		end

		return a, b
	end

	local function server_context(self)
		local kind = self._area_template_name

		if not PLAYER_TEMPLATES[kind] then
			return false
		end

		local source_unit = self._source_unit
		local owner = source_unit and core.player_category(source_unit) or false
		local by_owner = _server_contexts[kind]

		if not by_owner then
			by_owner = {}
			_server_contexts[kind] = by_owner
		end

		local context = by_owner[owner]

		if not context then
			context = { kind = kind, owner = owner or nil }
			by_owner[owner] = context
		end

		return context
	end

	local function husk_context(self)
		local kind = self._area_template_name

		if not PLAYER_TEMPLATES[kind] then
			return false
		end

		local context = _husk_contexts[kind]

		if not context then
			context = { kind = kind }
			_husk_contexts[kind] = context
		end

		return context
	end

	for _, method in ipairs({ "_create_liquid", "_set_filled" }) do
		mod:hook(CLASS.LiquidAreaExtension, method, function(func, self, ...)
			return call_in_context(server_context(self), func, self, ...)
		end)
	end

	for _, method in ipairs({ "_add_liquid", "_set_liquid_filled" }) do
		mod:hook(CLASS.HuskLiquidAreaExtension, method, function(func, self, ...)
			return call_in_context(husk_context(self), func, self, ...)
		end)
	end

	local function blast_owner(kind, position)
		if not position then
			return nil
		end

		local t = core.gameplay_time()
		local owner, nearest = nil, RADIUS

		for i = 1, #_blasts do
			local blast = _blasts[i]
			local age = t - blast.t

			if blast.kind == kind and age >= 0 and age <= WINDOW then
				local distance = Vector3.distance(position, blast.at:unbox())

				if distance <= nearest then
					owner, nearest = blast.owner, distance
				end
			end
		end

		return owner
	end

	function pools.owner(effect_name, position)
		local context = POOL_EFFECTS[effect_name] and _context

		if not context then
			return nil
		end

		return context.owner or blast_owner(context.kind, position)
	end

	function pools.remember(effect_name, owner, position)
		local kind = BLASTS[effect_name]

		if not kind or not owner or not position then
			return
		end

		table.insert(_blasts, 1, { kind = kind, owner = owner, at = Vector3Box(position), t = core.gameplay_time() })

		if #_blasts > MAX_BLASTS then
			_blasts[#_blasts] = nil
		end
	end

	function pools.clear()
		for i = #_blasts, 1, -1 do
			_blasts[i] = nil
		end
	end

	return pools
end
