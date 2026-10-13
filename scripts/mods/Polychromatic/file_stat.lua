local DIRECTORY_ATTRIBUTE = 16
local GET_FILE_EX_INFO_STANDARD = 0

local pcall = pcall
local rawget = rawget
local tonumber = tonumber
local string_format = string.format

local function build()
	local Mods = rawget(_G, "Mods")
	local ffi = Mods and Mods.lua and Mods.lua.ffi

	if not ffi then
		return nil
	end

	local ok = pcall(function()
		if not pcall(function() return ffi.C.GetFileAttributesExA end) then
			ffi.cdef("int GetFileAttributesExA(const char* name, int level, void* info);")
		end
	end)

	if not ok then
		return nil
	end

	local get_attributes = ffi.C.GetFileAttributesExA
	local info = ffi.new("uint32_t[9]")

	return function(path)
		local called, result = pcall(get_attributes, path, GET_FILE_EX_INFO_STANDARD, info)

		if not called or result == 0 then
			return nil
		end

		local attributes = tonumber(info[0])

		if attributes % (DIRECTORY_ATTRIBUTE * 2) >= DIRECTORY_ATTRIBUTE then
			return nil
		end

		local size = tonumber(info[7]) * 4294967296 + tonumber(info[8])

		return size, string_format("%08x%08x", tonumber(info[6]), tonumber(info[5]))
	end
end

local built, stat = pcall(build)

return { stat = built and stat or nil }
