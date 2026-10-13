local SHIELD_ROOT = "content/mods/polychromatic/psyker_shield/mhue/"
local WALL = { set = "shield", root = SHIELD_ROOT, slot = "\x70\xd3\x0a\x22\xd5\x53\xd2\x40", material = "def2e849fd09c6b2", gate = true }
local DOME = { set = "shield", root = SHIELD_ROOT, slot = "\x23\xf5\xa9\xb5\x30\xfa\x3a\x4c", material = "b08e68a753ee521a", gate = true }

return {
	units = {
		["876015142d45c157"] = WALL,
		["9979146133990631"] = WALL,
		["0c6e437f6e1180c7"] = DOME,
	},
}
