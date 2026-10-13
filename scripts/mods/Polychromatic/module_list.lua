local CDEF_TYPE = "AssetRedirect_MODULES_CDEF"
local DLL_NAME = "asset-redirect.dll"
local OUT_CAP = 65536
local REGISTRY_KEY = "__polychromatic_registry"
local INVALID_ATTRIBUTES = 4294967295
local DIRECTORY_ATTRIBUTE = 16

local rawget = rawget
local rawset = rawset
local pcall = pcall
local tostring = tostring
local type = type

local Mods = rawget(_G, "Mods")
local ffi = Mods and Mods.lua and Mods.lua.ffi
local cjson = rawget(_G, "cjson")

local module_list = {}
local _lib = nil
local _lib_error = nil
local _logged = false

local function folder(mod)
	return mod:get_internal_data("load_order_name") or mod:get_name()
end

local function log_once(mod, why)
	if not _logged then
		_logged = true
		mod:info("module list unavailable: %s", tostring(why))
	end
end

local function native(mod)
	if _lib or _lib_error then
		return _lib, _lib_error
	end

	if not ffi or not cjson then
		_lib_error = "ffi or cjson is unavailable"

		return nil, _lib_error
	end

	if not pcall(ffi.typeof, CDEF_TYPE) then
		ffi.cdef([[
			typedef struct { int unused; } AssetRedirect_MODULES_CDEF;
			int AssetRedirect_ListModules(const char* modules_dir, char* out, int cap);
		]])
	end

	local ok, lib = pcall(ffi.load, "../mods/" .. folder(mod) .. "/bin/" .. DLL_NAME)

	if not ok then
		_lib_error = tostring(lib)

		return nil, _lib_error
	end

	if not pcall(function() return lib.AssetRedirect_ListModules end) then
		_lib_error = "Polychromatic's asset redirect DLL predates the module list"

		return nil, _lib_error
	end

	_lib = lib

	return _lib
end

function module_list.list(mod)
	local lib, why = native(mod)

	if not lib then
		log_once(mod, why)

		return {}
	end

	local out = ffi.new("char[?]", OUT_CAP)
	local ok, written = pcall(lib.AssetRedirect_ListModules, "mods/" .. folder(mod) .. "/modules", out, OUT_CAP)

	if not ok or written < 0 then
		log_once(mod, ok and "AssetRedirect_ListModules failed" or written)

		return {}
	end

	local decoded_ok, decoded = pcall(cjson.decode, ffi.string(out))

	if not decoded_ok or type(decoded) ~= "table" or not decoded.ok or type(decoded.modules) ~= "table" then
		log_once(mod, decoded_ok and "unexpected module list reply" or decoded)

		return {}
	end

	return decoded.modules
end

function module_list.has_folder(path)
	if not ffi then
		return true
	end

	if not pcall(function() return ffi.C.GetFileAttributesA end) and not pcall(ffi.cdef, "unsigned long GetFileAttributesA(const char* path);") then
		return true
	end

	local ok, attributes = pcall(ffi.C.GetFileAttributesA, path)

	if not ok then
		return true
	end

	attributes = tonumber(attributes)

	return attributes ~= INVALID_ATTRIBUTES and attributes % (DIRECTORY_ATTRIBUTE * 2) >= DIRECTORY_ATTRIBUTE
end

function module_list.registry(mod, rebuild)
	local cached = rawget(_G, REGISTRY_KEY)

	if cached and not rebuild then
		return cached
	end

	local build = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/module_registry")
	local base_version = mod.get_metadata and mod:get_metadata("version") or "2.0.0"
	local registry = build({
		api = 1,
		base_version = base_version,
		list = function()
			return module_list.list(mod)
		end,
		load = function(id)
			return mod:io_dofile("Polychromatic/modules/" .. id .. "/module")
		end,
		has_folder = function(id, rel)
			local root = "../mods/" .. folder(mod) .. "/modules/"

			if not module_list.has_folder(root .. id) then
				return true
			end

			return module_list.has_folder(root .. id .. "/" .. rel)
		end,
		log = function(...)
			mod:info(...)
		end,
	})

	rawset(_G, REGISTRY_KEY, registry)

	return registry
end

return module_list
