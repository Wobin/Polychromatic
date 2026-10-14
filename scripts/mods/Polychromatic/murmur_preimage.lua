local _u64, _murmur_m, _murmur_inverse = nil, nil, nil

local function murmur_preimage(hex)
	if type(hex) ~= "string" or #hex ~= 16 then
		return nil
	end

	local hi, lo = tonumber(string.sub(hex, 1, 8), 16), tonumber(string.sub(hex, 9, 16), 16)
	local bit_lib = rawget(_G, "bit")

	if not hi or not lo or not bit_lib then
		return nil
	end

	if not _u64 then
		local mods = rawget(_G, "Mods")
		local ffi = mods and mods.lua and mods.lua.ffi

		if not ffi then
			local ok, lib = pcall(require, "ffi")

			ffi = ok and lib or nil
		end

		if not ffi then
			return nil
		end

		_u64 = ffi.typeof("uint64_t")
		_murmur_m = _u64(0xc6a4a793) * 4294967296 + 0x5bd1e995
		_murmur_inverse = _murmur_m

		for _ = 1, 6 do
			_murmur_inverse = _murmur_inverse * (2 - _murmur_m * _murmur_inverse)
		end
	end

	local bxor, rshift = bit_lib.bxor, bit_lib.rshift
	local h = _u64(hi) * 4294967296 + lo

	h = bxor(h, rshift(h, 47)) * _murmur_inverse
	h = bxor(h, rshift(h, 47)) * _murmur_inverse

	local k = bxor(h, _murmur_m * 8) * _murmur_inverse

	k = bxor(k, rshift(k, 47)) * _murmur_inverse

	local bytes = {}

	for i = 1, 8 do
		bytes[i] = string.char(tonumber(bit_lib.band(k, 255)))
		k = rshift(k, 8)
	end

	local name = table.concat(bytes)

	if string.find(name, "\0", 1, true) then
		return nil
	end

	return name
end

return murmur_preimage
