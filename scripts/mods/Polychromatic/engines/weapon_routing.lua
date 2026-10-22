return function(mod, core, data_list)
	local effect_routes = {}
	local effect_slots = {}

	for _, data in ipairs(data_list) do
		local effects = type(data) == "table" and data.effects
		local slot = type(data) == "table" and type(data.slot) == "string" and data.slot or "slot_primary"

		if type(effects) == "table" then
			for effect_name, templates in pairs(effects) do
				if effect_routes[effect_name] == nil and type(templates) == "table" then
					local routes = {}

					for template_name, set_id in pairs(templates) do
						if type(set_id) == "string" then
							routes[template_name] = set_id
						end
					end

					effect_routes[effect_name] = routes
					effect_slots[effect_name] = slot
				end
			end
		end
	end

	local function template_of(unit, slot)
		if not unit or not Unit.alive(unit) then
			return nil
		end

		local extension = ScriptUnit.has_extension(unit, "visual_loadout_system")
		local template = extension and extension.weapon_template_from_slot and extension:weapon_template_from_slot(slot)

		return template and template.name or nil
	end

	return {
		resolve = function(set_id, effect_name, unit)
			local routes = effect_name and effect_routes[effect_name]

			if not routes then
				return set_id, false
			end

			local template = template_of(unit, effect_slots[effect_name])

			return template and routes[template] or nil, true
		end,
		routed = function(effect_name)
			return effect_routes[effect_name] ~= nil
		end,
	}
end
