local function version_less(a, b)
	local function parts(version)
		local out = {}

		for number in string.gmatch(tostring(version), "%d+") do
			out[#out + 1] = tonumber(number)
		end

		return out
	end

	local pa, pb = parts(a), parts(b)

	for i = 1, math.max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0

		if x ~= y then
			return x < y
		end
	end

	return false
end

local VALID_CATEGORIES = { mine = true, team = true, enemy = true }

local function malformed(manifest)
	local sources, packages, engines = manifest.sources, manifest.packages, manifest.engines

	if sources ~= nil and type(sources) ~= "table" then
		return "malformed sources"
	end

	if packages ~= nil and type(packages) ~= "table" then
		return "malformed packages"
	end

	if engines ~= nil and type(engines) ~= "table" then
		return "malformed engines"
	end

	if manifest.data ~= nil and type(manifest.data) ~= "table" then
		return "malformed data"
	end

	for _, file in pairs(manifest.data or {}) do
		if type(file) ~= "string" then
			return "malformed data"
		end
	end

	for _, source in ipairs(sources or {}) do
		if type(source) ~= "table" or type(source.id) ~= "string" or type(source.label) ~= "string" or type(source.description) ~= "string" or type(source.categories) ~= "table" or #source.categories == 0 then
			return "malformed sources"
		end

		for _, category in ipairs(source.categories) do
			if not VALID_CATEGORIES[category] then
				return "malformed sources"
			end
		end
	end

	for _, name in ipairs(packages or {}) do
		if type(name) ~= "string" then
			return "malformed packages"
		end
	end

	for _, engine in ipairs(engines or {}) do
		if type(engine) ~= "string" then
			return "malformed engines"
		end
	end

	return nil
end

local function same_payload(first, entry, module, identity)
	if first.sha256 ~= entry.sha256 or first.sha256 == nil and first.file ~= entry.file then
		return false
	end

	if not identity then
		return true
	end

	local kept, offered = identity(first, first.module), identity(entry, module)

	return kept == nil or offered == nil or kept == offered
end

local function merge_redirects(list, identity, into)
	local merged, conflicts, by_stock = into or {}, {}, {}

	for _, entry in ipairs(merged) do
		if type(entry) == "table" and type(entry.stock) == "string" and not by_stock[entry.stock] then
			by_stock[entry.stock] = entry
		end
	end

	for _, group in ipairs(list or {}) do
		for _, entry in ipairs(group.list or {}) do
			local malformed_entry = type(entry) ~= "table" or type(entry.stock) ~= "string" or type(entry.file) ~= "string"
			local first = not malformed_entry and by_stock[entry.stock]

			if malformed_entry then
				conflicts[#conflicts + 1] = { stock = type(entry) == "table" and tostring(entry.stock) or tostring(entry), module = group.module, reason = "malformed redirect" }
			elseif not first then
				local copy = {}

				for key, value in pairs(entry) do
					copy[key] = value
				end

				copy.module = group.module
				by_stock[entry.stock] = copy
				merged[#merged + 1] = copy
			elseif not same_payload(first, entry, group.module, identity) then
				conflicts[#conflicts + 1] = { stock = entry.stock, module = group.module, kept = first.module, reason = "different contents" }
			end
		end
	end

	return merged, conflicts
end

local function build(opts)
	local result = { modules = {}, skipped = {}, sources = {}, engines = {}, packages = {}, merge_redirects = merge_redirects }
	local source_ids, package_names = {}, {}

	local function skip(id, reason)
		result.skipped[#result.skipped + 1] = { id = id, reason = reason }
		opts.log("module %s not loaded: %s", tostring(id), reason)
	end

	local function find_clash(manifest)
		local seen_sources, seen_packages = {}, {}

		for _, source in ipairs(manifest.sources or {}) do
			if seen_sources[source.id] then
				return "source " .. source.id .. " is listed twice"
			end

			if source_ids[source.id] then
				return "source " .. source.id .. " is already provided by " .. source_ids[source.id]
			end

			seen_sources[source.id] = true
		end

		for _, name in ipairs(manifest.packages or {}) do
			if seen_packages[name] then
				return "package " .. name .. " is listed twice"
			end

			if package_names[name] then
				return "package " .. name .. " is already provided by " .. package_names[name]
			end

			seen_packages[name] = true
		end

		return nil
	end

	local function missing_packages(id, manifest)
		if not opts.has_folder then
			return nil
		end

		local missing = {}

		for _, name in ipairs(manifest.packages or {}) do
			if not opts.has_folder(id, "Packages/" .. name) then
				missing[#missing + 1] = name
			end
		end

		if #missing > 0 then
			return "packages missing: " .. table.concat(missing, ", ")
		end

		return nil
	end

	local ids = opts.list() or {}

	table.sort(ids)

	for _, id in ipairs(ids) do
		local ok, manifest, load_err = pcall(opts.load, id)

		if not ok then
			skip(id, tostring(manifest))
		elseif type(manifest) ~= "table" then
			skip(id, load_err or "module.lua did not return a table")
		elseif type(manifest.id) ~= "string" then
			skip(id, "manifest has no id")
		elseif manifest.id ~= id then
			skip(id, string.format("manifest id %s does not match folder %s", manifest.id, tostring(id)))
		elseif type(manifest.api) ~= "number" or manifest.api > opts.api then
			skip(id, string.format("needs manifest api %s, this base supports %d", tostring(manifest.api), opts.api))
		elseif manifest.min_base and version_less(opts.base_version, manifest.min_base) then
			skip(id, string.format("needs base %s, this base is %s", manifest.min_base, tostring(opts.base_version)))
		else
			local problem = malformed(manifest) or find_clash(manifest) or missing_packages(id, manifest)

			if problem then
				skip(id, problem)
			else
				result.modules[#result.modules + 1] = manifest

				for _, source in ipairs(manifest.sources or {}) do
					source_ids[source.id] = id
					source.module = id
					result.sources[#result.sources + 1] = source
				end

				for _, name in ipairs(manifest.packages or {}) do
					package_names[name] = id
					result.packages[#result.packages + 1] = { module = id, name = name }
				end

				for _, engine in ipairs(manifest.engines or {}) do
					result.engines[engine] = result.engines[engine] or {}
					result.engines[engine][#result.engines[engine] + 1] = { module = id, file = (manifest.data or {})[engine] }
				end
			end
		end
	end

	table.sort(result.sources, function(a, b)
		return a.label < b.label
	end)

	return result
end

return setmetatable({ merge_redirects = merge_redirects }, {
	__call = function(_, opts)
		return build(opts)
	end,
})
