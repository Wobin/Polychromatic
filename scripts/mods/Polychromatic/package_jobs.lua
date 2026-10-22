local OUT_CAP = 65536
local START_CAP = 4096
local POLL = "AssetRedirect_PackagesPoll"

local pcall = pcall
local type = type

return function(ffi, json)
	local jobs = { POLL = POLL }
	local _out = nil
	local _cap = 0
	local _start = nil

	function jobs.decode(name, text)
		local ok, decoded = pcall(json.decode, text)

		if not ok or type(decoded) ~= "table" then
			return { ok = false, unreadable = true, error = name .. " returned unreadable output" }
		end

		return decoded
	end

	function jobs.start_buffer()
		if not _start then
			_start = ffi.new("char[?]", START_CAP)
		end

		return _start, START_CAP
	end

	function jobs.start_result(name)
		return jobs.decode(name, ffi.string(_start))
	end

	function jobs.poll(lib, expected)
		if not _out then
			_out = ffi.new("char[?]", OUT_CAP)
			_cap = OUT_CAP
		end

		local polled = lib[POLL](_out, _cap)

		if polled == 0 then
			return nil
		end

		if polled > 1 then
			_out = ffi.new("char[?]", polled)
			_cap = polled

			return nil
		end

		if polled ~= 1 then
			return { ok = false, error = "the " .. expected .. " job finished without a result", job = expected }
		end

		local result = jobs.decode(POLL, ffi.string(_out))

		if not result.unreadable and result.job ~= expected then
			return nil
		end

		return result
	end

	return jobs
end
