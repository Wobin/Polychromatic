local STAFF_TEMPLATE_SETS = {
	forcestaff_p1_m1 = "staff_trauma",
	forcestaff_p3_m1 = "surge",
	forcestaff_p4_m1 = "staff_voidstrike",
}
local STAFF_EFFECT_SETS = {
	["content/fx/particles/weapons/force_staff/force_staff_explosion"] = "staff_trauma",
	["content/fx/particles/weapons/force_staff/force_staff_explosion_indicator"] = "staff_trauma",
	["content/fx/particles/weapons/force_staff/3p_force_staff_explosion_indicator"] = "staff_trauma",
	["content/fx/particles/weapons/bfg_staff/psyker_bfg_projectile_01"] = "staff_voidstrike",
	["content/fx/particles/weapons/bfg_staff/psyker_bfg_projectile_charge_01"] = "staff_voidstrike",
	["content/fx/particles/weapons/bfg_staff/psyker_bfg_projectile_charge_done_01"] = "staff_voidstrike",
	["content/fx/particles/weapons/force_staff/force_staff_projectile_cast_02"] = "staff_voidstrike",
}

return function(mod, core, data_list)
	local function staff_set_of(unit)
		if not unit or not Unit.alive(unit) then
			return nil
		end

		local extension = ScriptUnit.has_extension(unit, "visual_loadout_system")
		local template = extension and extension.weapon_template_from_slot and extension:weapon_template_from_slot("slot_secondary")

		return template and STAFF_TEMPLATE_SETS[template.name]
	end

	return {
		resolve = function(effect_name, unit)
			return STAFF_EFFECT_SETS[effect_name] or staff_set_of(unit) or "staff_trauma"
		end,
	}
end
