local CDEF_TYPE = "Polychromatic_QPC_CDEF"

local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local os_clock = os.clock
local string_format = string.format
local table_concat = table.concat

local function build_clock()
	local ffi = rawget(_G, "Mods") and Mods.lua and Mods.lua.ffi

	if not ffi then
		return nil
	end

	local ok, now = pcall(function()
		if not pcall(ffi.typeof, CDEF_TYPE) then
			ffi.cdef([[
				typedef struct { int unused; } Polychromatic_QPC_CDEF;
				int QueryPerformanceCounter(int64_t* count);
				int QueryPerformanceFrequency(int64_t* freq);
			]])
		end

		local C = ffi.C
		local query_counter = C.QueryPerformanceCounter
		local query_frequency = C.QueryPerformanceFrequency
		local counter = ffi.new("int64_t[1]")
		local frequency = ffi.new("int64_t[1]")

		if query_frequency(frequency) == 0 or query_counter(counter) == 0 then
			return nil
		end

		local per_ms = tonumber(frequency[0]) / 1000

		if not (per_ms > 0) then
			return nil
		end

		return function()
			query_counter(counter)

			return tonumber(counter[0]) / per_ms
		end
	end)

	return ok and now or nil
end

local function cpu_clock()
	return os_clock() * 1000
end

local now = build_clock() or cpu_clock
local ok_probe, probe = pcall(now)

if not ok_probe or type(probe) ~= "number" then
	now = cpu_clock
end

local function start()
	local t0 = now()
	local mark = t0
	local names, values = {}, {}
	local timer = {}

	function timer.mark()
		mark = now()
	end

	function timer.lap(name)
		local at = now()

		names[#names + 1] = name
		values[#values + 1] = at - mark
		mark = at
	end

	function timer.line(title, order)
		local total = now() - t0
		local sum = 0
		local parts = {}
		local by_name = {}

		for i = 1, #names do
			sum = sum + values[i]
			by_name[names[i]] = (by_name[names[i]] or 0) + values[i]
		end

		for i = 1, #(order or names) do
			local name = order and order[i] or names[i]

			parts[#parts + 1] = string_format("%s %.2f", name, by_name[name] or 0)
		end

		parts[#parts + 1] = string_format("other %.2f", total > sum and total - sum or 0)

		return string_format("startup: %s %.2f ms (%s)", title, total, table_concat(parts, ", "))
	end

	return timer
end

local function detail()
	local groups, values, kinds = {}, {}, {}
	local mark = now()
	local recorder = {}

	local function slot(group, name)
		local list = values[group]

		if not list then
			list = { names = {} }
			values[group] = list
			groups[#groups + 1] = group
		end

		if list[name] == nil then
			list.names[#list.names + 1] = name
			list[name] = 0
		end

		return list
	end

	function recorder.mark()
		mark = now()
	end

	function recorder.lap(group, name)
		local at = now()
		local list = slot(group, name)

		list[name] = list[name] + (at - mark)
		mark = at
	end

	function recorder.count(group, name, n)
		local list = slot(group, name)

		kinds[group .. "/" .. name] = true
		list[name] = list[name] + (n or 1)
	end

	function recorder.line()
		local parts = {}

		for i = 1, #groups do
			local group = groups[i]
			local list = values[group]
			local items = {}

			for j = 1, #list.names do
				local name = list.names[j]

				if kinds[group .. "/" .. name] then
					items[#items + 1] = string_format("%s %d", name, list[name])
				else
					items[#items + 1] = string_format("%s %.2f", name, list[name])
				end
			end

			parts[#parts + 1] = string_format("%s{%s}", group, table_concat(items, ", "))
		end

		return "startup: detail " .. table_concat(parts, " ")
	end

	return recorder
end

return { start = start, detail = detail }
