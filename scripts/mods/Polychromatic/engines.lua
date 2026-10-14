local FILES = { "weapon_glow", "colour_channels", "scene_lights", "unit_hues", "pools", "burn", "staff_routing", "blitz_routing", "decal_swap", "bolt_palettes", "live_tint" }
local REQUIRES = {
	pools = { "live_tint" },
	scene_lights = { "live_tint" },
	burn = { "live_tint" },
	decal_swap = { "live_tint" },
	bolt_palettes = { "live_tint" },
}
local ENGINE_ROOT = "Polychromatic/scripts/mods/Polychromatic/engines/"
local MODULE_ROOT = "Polychromatic/modules/"

local ipairs = ipairs
local pcall = pcall
local select = select
local tostring = tostring
local type = type
local unpack = unpack

local engines = {}

local function pack(...)
	return { n = select("#", ...), ... }
end

local function data_for(mod, name, entries)
	local list = {}

	for _, entry in ipairs(entries) do
		if entry.file then
			local data = mod:io_dofile(MODULE_ROOT .. tostring(entry.module) .. "/data/" .. entry.file)

			if type(data) == "table" then
				list[#list + 1] = data
			else
				mod:info("engine %s: data %s/%s did not load", name, tostring(entry.module), tostring(entry.file))
			end
		end
	end

	return list
end

local function build(mod, name, entries, core)
	local factory = mod:io_dofile(ENGINE_ROOT .. name)

	if type(factory) ~= "function" then
		error("engine file did not load", 0)
	end

	return factory(mod, core, data_for(mod, name, entries))
end

local function script_api(mod, id, core)
	local state = { failed = false }

	local function disable(err)
		if not state.failed then
			state.failed = true
			mod:info("module %s script disabled: %s", tostring(id), tostring(err))
		end
	end

	local function register_hook(target, method, fn, safe)
		if type(target) ~= "table" or type(method) ~= "string" or type(fn) ~= "function" then
			error("register_hook needs a target table, a method name and a function", 2)
		end

		if safe then
			mod:hook_safe(target, method, function(...)
				if state.failed then
					return
				end

				local ok, err = pcall(fn, ...)

				if not ok then
					disable(err)
				end
			end)

			return
		end

		local depth, current, called, stored = 0, nil, false, false
		local got, res = { n = 0 }, { n = 0 }

		local function store(...)
			local n = select("#", ...)

			got.n = n

			for i = 1, n do
				got[i] = (select(i, ...))
			end

			stored = true

			return ...
		end

		local function original(...)
			called = true

			return store(current(...))
		end

		local function capture(ok, ...)
			local n = select("#", ...)

			res.n = n

			for i = 1, n do
				res[i] = (select(i, ...))
			end

			return ok
		end

		local function nested(func, ...)
			local nested_called, nested_got = false, nil

			local function nested_original(...)
				nested_called = true
				nested_got = pack(func(...))

				return unpack(nested_got, 1, nested_got.n)
			end

			local result = pack(pcall(fn, nested_original, ...))

			if result[1] then
				return unpack(result, 2, result.n)
			end

			if nested_called and not nested_got then
				error(result[2], 0)
			end

			disable(result[2])

			if nested_called then
				return unpack(nested_got, 1, nested_got.n)
			end

			return func(...)
		end

		mod:hook(target, method, function(func, ...)
			if state.failed then
				return func(...)
			end

			if depth > 0 then
				return nested(func, ...)
			end

			depth, current, called, stored = 1, func, false, false

			local ok = capture(pcall(fn, original, ...))

			depth, current = 0, nil

			if ok then
				return unpack(res, 1, res.n)
			end

			local err = res[1]

			if called and not stored then
				error(err, 0)
			end

			disable(err)

			if called then
				return unpack(got, 1, got.n)
			end

			return func(...)
		end)
	end

	return {
		profile_for = core.profile_for,
		owner_of = core.category_of_unit,
		resolve_set = core.resolve_set,
		register_hook = register_hook,
	}, disable
end

local function run_scripts(mod, registry, core)
	for _, manifest in ipairs(registry.modules or {}) do
		if type(manifest.script) == "string" then
			local api, disable = script_api(mod, manifest.id, core)
			local script = mod:io_dofile(MODULE_ROOT .. tostring(manifest.id) .. "/" .. manifest.script)
			local ok, err = false, "script did not load"

			if type(script) == "function" then
				ok, err = pcall(script, api)
			end

			if not ok then
				disable(err)
			end
		end
	end
end

local function active_engines(declared)
	local active = {}

	for _, name in ipairs(FILES) do
		if declared[name] then
			active[name] = declared[name]

			for _, required in ipairs(REQUIRES[name] or {}) do
				active[required] = active[required] or declared[required] or {}
			end
		end
	end

	return active
end

local KNOWN = {}

for _, name in ipairs(FILES) do
	KNOWN[name] = true
end

function engines.known(name)
	return KNOWN[name] == true
end

local function report_unknown(mod, declared)
	local names = {}

	for name in pairs(declared) do
		if not KNOWN[name] then
			names[#names + 1] = tostring(name)
		end
	end

	table.sort(names)

	for _, name in ipairs(names) do
		local from = {}

		for _, entry in ipairs(declared[name]) do
			from[#from + 1] = tostring(entry.module)
		end

		mod:info("engine %s unknown, skipped (declared by %s)", name, table.concat(from, ", "))
	end
end

function engines.load(mod, registry, core)
	local loaded, disabled = core.engines or {}, {}
	local active = active_engines(registry.engines or {})

	local detail = core.detail

	core.engines = loaded
	report_unknown(mod, registry.engines or {})

	for _, name in ipairs(FILES) do
		local entries = active[name]

		if entries then
			local ok, result = pcall(build, mod, name, entries, core)

			if ok then
				loaded[name] = result
			else
				disabled[name] = tostring(result)
				mod:info("engine %s disabled: %s", name, disabled[name])
			end

			if detail then
				detail.lap("engines", name)
			end
		end
	end

	run_scripts(mod, registry, core)

	if detail then
		detail.lap("engines", "scripts")
	end

	return loaded, disabled
end

return engines
