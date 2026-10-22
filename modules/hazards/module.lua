return {
	api = 2,
	min_base = "3.0.0",
	id = "hazards",
	label = "Hazards",
	version = "1.1.0",
	sources = {
		{ id = "sniper", categories = { "enemy" }, label = "Enemy sniper laser", description = "The Scab Sniper targeting laser and its shot. Stock red is easy to lose against warm backgrounds.", no_rainbow = true },
		{ id = "barrel", categories = { "enemy" }, show_label = "Show barrel fire", label = "Explosive barrels", description = "The fire of exploding red barrels in missions. The brightest flame layers recolour; the smoke, sparks and one outer flame layer stay stock." },
	},
	packages = { "hazards_fire", "hazards_las" },
	engines = { "live_tint", "colour_channels", "bolt_palettes", "scene_lights" },
	data = {
		las_redirects = "las_redirects",
		flash_effects = "flash_effects",
		encoded_effects = "encoded_effects",
		ca_palettes = "palettes",
		ca_assets = "ca_assets",
		scene_lights = "scene_lights",
	},
}
