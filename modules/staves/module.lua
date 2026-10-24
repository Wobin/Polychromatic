return {
	api = 2,
	min_base = "3.1.0",
	id = "staves",
	label = "Staves",
	version = "1.2.0",
	sources = {
		{
			id = "staff", categories = { "mine", "team" }, label = "Staff: Inferno", description = "Psyker Inferno staff streams and their wall impacts. The glow an impact leaves on the ground takes the nearest of 12 hues.",
			widgets = {
				{ setting_id = "soulblaze", type = "checkbox", default_value = true },
			},
		},
		{ id = "surge", categories = { "mine", "team" }, label = "Staff: Surge", description = "Psyker Surge staff lightning: the bolts between hands and targets, the jumps between targets and the strike on each target. Colour, saturation and brightness change live; the floor glow follows the nearest of 12 hues. The basic projectile from the primary attack and its impacts are included. The hand sparks stay stock.", no_hidden = true },
		{ id = "staff_trauma", categories = { "mine", "team" }, label = "Staff: Trauma", description = "Psyker Trauma staff: the basic projectile and its impacts, the charged explosion, its light and the aiming reticule." },
		{ id = "staff_voidstrike", categories = { "mine", "team" }, label = "Staff: Voidstrike", description = "Psyker Voidstrike staff: the basic projectile and its impacts, the charge-up sphere, the charged blast and its impact." },
	},
	packages = { "staves_flame", "staves_soul", "staves_staff", "staves_surge" },
	engines = { "live_tint", "colour_channels", "burn", "decal_swap", "scene_lights", "staff_routing", "bolt_palettes" },
	data = {
		redirects = "redirects",
		las_redirects = "las_redirects",
		soul_slots = "soul_slots",
		encoded_effects = "encoded_effects",
		ca_palettes = "palettes",
		ca_assets = "ca_assets",
		decal_swap = "decal_swap",
		burn = "burn",
		burn_redirects = "burn_redirects",
		scene_lights = "scene_lights",
	},
}
