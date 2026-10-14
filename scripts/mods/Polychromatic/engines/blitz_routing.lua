return function(mod, core, data_list)
	local template_sets = {}

	for _, data in ipairs(data_list) do
		local templates = type(data) == "table" and data.templates

		if type(templates) == "table" then
			for template_name, set_id in pairs(templates) do
				if template_sets[template_name] == nil and type(set_id) == "string" then
					template_sets[template_name] = set_id
				end
			end
		end
	end

	local function blitz_set_of(unit)
		if not unit or not Unit.alive(unit) then
			return nil
		end

		local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
		local inventory = unit_data and unit_data.read_component and unit_data:read_component("inventory")
		local slot = inventory and inventory.wielded_slot
		local extension = slot and ScriptUnit.has_extension(unit, "visual_loadout_system")
		local template = extension and extension.weapon_template_from_slot and extension:weapon_template_from_slot(slot)

		return template and template_sets[template.name]
	end

	return {
		resolve = blitz_set_of,
	}
end
