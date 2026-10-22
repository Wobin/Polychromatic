return {
	weapons = {
		{
			pattern = "/powermaul_p3_",
			set = "arc_maul",
			variables = {
				{ name = "emissive_color", stock = { 0.003, 0.109, 0.199 } },
			},
		},
		{
			pattern = "/arc_rifle_p1_",
			set = "arc",
			variables = {
				{ name = "\x53\xd0\x94\x9d\xac\x38\xa1\x83", stock = { 0.012, 0.471, 0.859 } },
			},
		},
		{
			pattern = "/powersword_p3_",
			set = "power_sword",
			slots = { "slot_primary" },
			variables = {
				{ name = "glow_color", stock = { 0.128, 0.713, 2.0 } },
			},
			hue_root = "content/mods/polychromatic/skitarii_sword/mhue/",
			hues = {
				["cf57a732bfa299a4"] = {
					{ slot = "\x7a\xf8\xfc\xd2\xc1\x32\x00\x8e", material = "b33f08ea3bb65545" },
				},
			},
		},
	},
}
