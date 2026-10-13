return {
	api = 1,
	id = "skitarii",
	label = "Skitarii",
	version = "1.0.0",
	sources = {
		{ id = "arc_maul", categories = { "mine", "team" }, label = "Arc maul", description = "Skitarii arc maul: the idle arcs on the head, the special's lightning and the coil glow. Colour, saturation and brightness change live.", no_hidden = true },
		{ id = "arc", categories = { "mine", "team" }, label = "Arc rifle", description = "Skitarii arc rifle beam lightning, arc chains and their strikes, the impact and its light, plus the arc rifle's glow. Colour, saturation and brightness change live.", no_hidden = true },
		{
			id = "skull", categories = { "mine", "team" }, label = "Servo-Skull flame", description = "The Skitarii companion servo-skull flamer.",
			widgets = {
				{ setting_id = "skull_burn", type = "checkbox", default_value = true },
			},
		},
		{ id = "skull_las", categories = { "mine", "team" }, label = "Servo-Skull las", description = "The Skitarii companion servo-skull's las shots: muzzle flash, beam, linger, impacts and scope glint." },
	},
	packages = { "skitarii_burn", "skitarii_flame", "skitarii_las", "skitarii_lightning" },
	engines = { "live_tint", "colour_channels", "burn", "weapon_glow", "bolt_palettes", "scene_lights" },
	data = {
		redirects = "redirects",
		las_redirects = "las_redirects",
		burn_redirects = "burn_redirects",
		spawn_vector_clouds = "spawn_vector_clouds",
		encoded_effects = "encoded_effects",
		burn_palettes = "burn_palettes",
		ca_palettes = "palettes",
		ca_assets = "ca_assets",
		burn = "burn",
		weapon_glow = "weapon_glow",
		scene_lights = "scene_lights",
	},
}
