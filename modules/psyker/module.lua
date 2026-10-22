return {
	api = 2,
	min_base = "3.0.0",
	id = "psyker",
	label = "Psyker",
	version = "1.1.0",
	sources = {
		{ id = "assail", categories = { "mine", "team" }, label = "Assail", description = "Psyker Assail: the knife trail, the critical trail, the hit flash on the target, the aim marker and the shards hovering at the hand while Assail is held. The trails take the nearest of 12 hues at full saturation and brightness; the hit flash, the aim marker and the shards follow colour, saturation and brightness live. Shared hit effects on armour and walls and blood stay stock.", no_hidden = true },
		{ id = "brain_burst", categories = { "mine", "team" }, label = "Brain Burst", description = "Psyker Brain Burst: the hand charge-up, the build-up, the target marker and the burst on the target. Colour, saturation and brightness change live.", no_hidden = true },
		{ id = "greatsword", categories = { "mine", "team" }, label = "Force greatsword", description = "Psyker two-hand force sword: charge, activation, the warp wisps at the fingertips, blocks, parries, the push and the arc thrown by the charged special." },
		{ id = "smite", categories = { "mine", "team" }, label = "Smite", description = "Psyker Smite: the lightning between hands and targets, the strike on each target, the hand and fingertip arcs, the charge-up and the target marker. Colour, saturation and brightness change live.", no_hidden = true },
		{
			id = "shield", categories = { "mine", "team" }, label = "Telekine Shield", description = "Psyker Telekine Shield, wall and dome. The shield takes the nearest of 12 hues at full saturation and brightness, so the brightness setting does not apply. With 'Change colour when damaged' ticked, a shield below that owner's threshold switches to the damaged colour, even when Colour is Base.", no_hidden = true,
			widgets = {
				{
					setting_id = "shield_mine_damage_gate",
					type = "checkbox",
					default_value = false,
					sub_widgets = {
						{ setting_id = "shield_mine_damage_threshold", type = "numeric", default_value = 50, range = { 1, 100 }, decimals_number = 0 },
						{ setting_id = "shield_mine_damaged_colour", type = "color", default_value = { 255, 255, 40, 20 }, has_alpha = false },
					},
				},
				{
					setting_id = "shield_team_damage_gate",
					type = "checkbox",
					default_value = false,
					sub_widgets = {
						{ setting_id = "shield_team_damage_threshold", type = "numeric", default_value = 50, range = { 1, 100 }, decimals_number = 0 },
						{ setting_id = "shield_team_damaged_colour", type = "color", default_value = { 255, 255, 40, 20 }, has_alpha = false },
					},
				},
			},
		},
	},
	packages = { "psyker_assail", "psyker_blitz", "psyker_greatsword", "psyker_shield" },
	engines = { "live_tint", "colour_channels", "blitz_routing", "unit_hues", "bolt_palettes", "weapon_glow" },
	data = {
		redirects = "redirects",
		las_redirects = "las_redirects",
		encoded_effects = "encoded_effects",
		unreachable_effects = "unreachable_effects",
		glow_particle_palettes = "glow_particle_palettes",
		ca_palettes = "palettes",
		ca_assets = "ca_assets",
		unit_hues = "unit_hues",
		blitz_routing = "blitz_routing",
		weapon_glow = "weapon_glow",
	},
}
