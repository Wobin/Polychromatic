return {
	api = 1,
	id = "grenades",
	label = "Grenades",
	version = "1.0.0",
	sources = {
		{ id = "chem_grenade", categories = { "mine", "team" }, label = "Grenade: Chem", description = "Hive Scum chem grenade: the blast, the gas trail, the held grenade's wisps and the lingering pool with its edge. Layers with baked colours stay stock. Colour, saturation and brightness change live." },
		{ id = "fire_grenade", categories = { "mine", "team" }, label = "Grenade: Fire", description = "The fire grenade blast, its light and the burning pool it leaves. Colour, saturation and brightness change live.", no_hidden = true },
		{ id = "flash_grenade", categories = { "mine", "team" }, label = "Grenade: Flash", description = "Hive Scum flash grenade: the flash. Layers with baked colours stay stock. Colour, saturation and brightness change live." },
		{ id = "smoke_grenade", categories = { "mine", "team" }, label = "Grenade: Smoke", description = "Smoke grenade: the burst, the trail and the smoke cloud. The cloud takes the nearest of 12 hues at full saturation and brightness when it forms.", no_hidden = true },
	},
	packages = { "grenades_fire", "grenades_grenade" },
	engines = { "live_tint", "colour_channels", "pools", "unit_hues", "scene_lights", "bolt_palettes" },
	data = {
		las_redirects = "las_redirects",
		encoded_effects = "encoded_effects",
		ca_palettes = "palettes",
		ca_assets = "ca_assets",
		pools = "pools",
		unit_hues = "unit_hues",
		scene_lights = "scene_lights",
	},
}
