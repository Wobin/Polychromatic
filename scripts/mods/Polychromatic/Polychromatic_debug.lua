return function(context)
	local mod = context.mod
	local REDIRECTS = context.redirects
	local PAYLOAD_DIR = context.payload_dir
	local SOUL_SLOTS = context.soul_slots
	local GLOW_SLOTS = context.glow_slots
	local EXTENDED_PACKAGES = context.extended_packages
	local SETS = context.sets
	local asset_redirect = context.asset_redirect
	local redirect_handles = context.redirect_handles
	local redirect_served = context.redirect_served
	local profile_for = context.profile_for
	local redshift_owns_sniper = context.redshift_owns_sniper
	local effect_stats = context.effect_stats
	local soul_load_ids = context.soul_load_ids
	local glow_load_ids = context.glow_load_ids
	local extended_load_ids = context.extended_load_ids

	local _bundle_redirects = {}
	local _logged_loads = {}

	for i = 1, #REDIRECTS do
		local stock = REDIRECTS[i].stock

		if #stock == 16 and string.find(stock, "^%x+$") then
			_bundle_redirects[stock] = i
		end
	end

	local function bundle_name(ffi, text)
		local u64 = ffi.typeof("uint64_t")
		local m = u64(0xc6a4a793) * 4294967296 + 0x5bd1e995
		local length = #text
		local h = u64(length) * m
		local blocks = length - length % 8

		for i = 1, blocks, 8 do
			local k = u64(0)

			for j = 7, 0, -1 do
				k = k * 256 + string.byte(text, i + j)
			end

			k = k * m
			k = bit.bxor(k, bit.rshift(k, 47))
			k = k * m
			h = bit.bxor(h, k) * m
		end

		local remainder = length % 8

		if remainder > 0 then
			local k = u64(0)

			for j = remainder - 1, 0, -1 do
				k = k * 256 + string.byte(text, blocks + 1 + j)
			end

			h = bit.bxor(h, k) * m
		end

		h = bit.bxor(h, bit.rshift(h, 47)) * m
		h = bit.bxor(h, bit.rshift(h, 47))

		return bit.tohex(h)
	end

	local function file_size(lua_io, path)
		local file = lua_io.open(path, "rb")

		if not file then
			return nil
		end

		local size = file:seek("end")

		file:close()

		return size
	end


	local function package_loaded(package_name, reference_name, prioritize, use_resident_loading)
		local flags = context.flags()
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi

		if not flags.debug_logging or type(package_name) ~= "string" or _logged_loads[package_name] or not ffi or not rawget(_G, "bit") then
			return
		end

		local bundle = bundle_name(ffi, package_name)
		local index = _bundle_redirects[bundle]

		if not index then
			return
		end

		_logged_loads[package_name] = true

		local entry = REDIRECTS[index]
		local state = asset_redirect and asset_redirect.state(redirect_handles[index]) or "no library"
		local lua_io = lua.io
		local payload_size = lua_io and file_size(lua_io, PAYLOAD_DIR .. entry.file)

		mod:info("redirected load: %s (bundle %s) by %s, prioritized %s, resident %s, state %s, payload size %s", package_name, bundle, tostring(reference_name), tostring(prioritize), tostring(use_resident_loading), tostring(state), tostring(payload_size))
	end

	local function native_stats(instance)
		local lua = rawget(_G, "Mods") and Mods.lua
		local ffi = lua and lua.ffi
		local cjson = rawget(_G, "cjson")
		local native = instance and instance.native

		if not ffi or not cjson or not native then
			return nil
		end

		local cap = 262144
		local out = ffi.new("char[?]", cap)

		if native.AssetRedirect_Stats(out, cap) ~= 1 then
			return nil
		end

		local ok, stats = pcall(cjson.decode, ffi.string(out))

		return ok and type(stats) == "table" and stats or nil
	end

	local function stats_by_stock(stats)
		local by_stock = {}
		local entries = stats and stats.entries

		if type(entries) ~= "table" then
			return by_stock
		end

		for _, entry in ipairs(entries) do
			if type(entry.key) == "string" then
				local key = string.gsub(string.lower(entry.key), "\\", "/")

				for i = 1, #REDIRECTS do
					local stock = REDIRECTS[i].stock

					if string.sub(key, -#stock) == stock then
						by_stock[stock] = entry
					end
				end
			end
		end

		return by_stock
	end

	local function package_state(load_ids, package)
		local id = load_ids[package]

		if not id then
			return "not requested"
		end

		return Managers.package:has_loaded_id(id) and "loaded" or "loading"
	end

	local function check_setup(quiet, once)
		local flags = context.flags()

		if once then
			if rawget(_G, "__polychromatic_setup_dumped") then
				return
			end

			rawset(_G, "__polychromatic_setup_dumped", true)
		end

		local instance = rawget(_G, "__asset_redirect_instance")
		local lua = rawget(_G, "Mods") and Mods.lua
		local ui = Managers.ui
		local sub_state = ui and ui:get_current_sub_state_name()

		if sub_state == nil or sub_state == "" then
			sub_state = "none"
		end

		mod:info("check: Polychromatic %s, sub state %s, gameplay gate %s, file access %s", tostring(mod.version), tostring(sub_state), tostring(flags.gameplay_running), tostring(lua ~= nil and lua.ffi ~= nil and lua.io ~= nil))

		if not instance then
			mod:info("check: asset redirect library not present")
		else
			local lib_version = asset_redirect and asset_redirect.version() or "none"

			mod:info("check: asset redirect library %s, dll %s, native %s, late %s, newer %s, error %s", tostring(lib_version), tostring(instance.dll_version), tostring(instance.native_state), tostring(instance.late), tostring(instance.newer_available), tostring(instance.native_error))
		end

		local stats = native_stats(instance)
		local by_stock = stats_by_stock(stats)

		if stats then
			mod:info("check: dll hooks installed %s, schema %s, dll entries %d", tostring(stats.installed), tostring(stats.schema), type(stats.entries) == "table" and #stats.entries or -1)

			if type(stats.counters) == "table" then
				for name, value in pairs(stats.counters) do
					if type(value) == "table" then
						local parts = {}

						for api, count in pairs(value) do
							parts[#parts + 1] = string.format("%s %s", tostring(api), tostring(count))
						end

						table.sort(parts)
						value = table.concat(parts, ", ")
					end

					mod:info("check: dll counter %s: %s", tostring(name), tostring(value))
				end
			end
		else
			mod:info("check: dll stats unavailable")
		end

		local counts = {}
		local served, total = 0, #redirect_handles

		for i = 1, total do
			local entry = REDIRECTS[i]
			local handle = redirect_handles[i]
			local state = asset_redirect.state(handle)
			local owner = asset_redirect.winner(handle)
			local dll = by_stock[entry.stock]

			counts[state] = (counts[state] or 0) + 1

			if redirect_served(state) then
				served = served + 1
			end

			mod:info("check: redirect %s -> %s: %s, winner %s, opens %s, finds %s, attrs %s, reason %s", entry.stock, entry.file, state, tostring(owner), tostring(dll and dll.opens), tostring(dll and dll.finds), tostring(dll and dll.attrs), tostring(handle and handle.reason))
		end

		local summary = {}

		for state, count in pairs(counts) do
			summary[#summary + 1] = state .. " " .. count
		end

		table.sort(summary)
		mod:info("check: redirects served %d of %d (%s)", served, total, table.concat(summary, ", "))
		mod:info("check: burn shader patch served %s, soulblaze %s, flamer burn %s, skull burn %s, redshift owns sniper %s", tostring(flags.burn_patch_served), tostring(flags.soulblaze), tostring(flags.flamer_burn), tostring(flags.skull_burn), tostring(redshift_owns_sniper()))

		if Managers.package then
			for i = 1, #SOUL_SLOTS do
				local slot = SOUL_SLOTS[i]

				mod:info("check: soul slot %s usable %s, package %s", slot.package, tostring(slot.usable), package_state(soul_load_ids, slot.package))
			end

			for kind, list in pairs(GLOW_SLOTS) do
				for i = 1, #list do
					local slot = list[i]

					mod:info("check: glow slot %s %s usable %s, package %s", kind, slot.package, tostring(slot.usable), package_state(glow_load_ids, slot.package))
				end
			end

			for i = 1, #EXTENDED_PACKAGES do
				local entry = EXTENDED_PACKAGES[i]

				mod:info("check: extended package %s: %s", entry.package, package_state(extended_load_ids, entry.package))
			end
		end

		for i = 1, #SETS do
			local set = SETS[i]

			for j = 1, #set.categories do
				local profile = profile_for(set.id, set.categories[j])

				mod:info("check: setting %s %s: show %s, mode %s, hue %.3f, saturation %.3f, brightness %s", set.id, set.categories[j], tostring(profile.show), tostring(profile.mode), profile.hue or 0, profile.saturation or 0, tostring(profile.brightness))
			end
		end

		local effects = {}

		for effect_name in pairs(effect_stats) do
			effects[#effects + 1] = effect_name
		end

		table.sort(effects)

		for i = 1, #effects do
			local stat = effect_stats[effects[i]]

			mod:info("check: effect %s [%s %s]: seen %d, applied %d, deferred %d, late %d, expired %d, substituted %d", effects[i], tostring(stat.set), tostring(stat.category), stat.seen, stat.applied, stat.deferred, stat.late, stat.expired, stat.substituted)
		end

		local dmf = get_mod("DMF")
		local mods = dmf and dmf.mods

		if type(mods) == "table" then
			local names = {}

			for name, other in pairs(mods) do
				local enabled = type(other) == "table" and other.is_enabled and other:is_enabled()

				names[#names + 1] = string.format("%s%s", name, enabled and "" or " (off)")
			end

			table.sort(names)
			mod:info("check: mods %s", table.concat(names, ", "))
		end

		local native_ok = instance ~= nil and instance.native_state == "ready"

		if quiet then
			return
		end

		mod:echo("Polychromatic %s: redirect library %s, redirects %d of %d served, %d effects seen. Details are in the console log.", tostring(mod.version), native_ok and "loaded" or "NOT loaded", served, total, #effects)

		if not native_ok then
			mod:echo("The asset-redirect.dll in Polychromatic/bin did not load (%s), so only las beams can be recoloured. Check it exists and was not quarantined by antivirus.", tostring(instance and instance.native_error))
		elseif served < total then
			mod:echo("%d redirects were refused, most likely a game update changed the files they replace.", total - served)
		end
	end

	return {
		check_setup = check_setup,
		package_loaded = package_loaded,
	}
end
