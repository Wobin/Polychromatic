return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Polychromatic` encountered an error loading the Darktide Mod Framework.")

		new_mod("Polychromatic", {
			mod_script       = "Polychromatic/scripts/mods/Polychromatic/Polychromatic",
			mod_data         = "Polychromatic/scripts/mods/Polychromatic/Polychromatic_data",
			mod_localization = "Polychromatic/scripts/mods/Polychromatic/Polychromatic_localization",
		})
	end,
	packages = {},
	load_after = { "Redshift" },
}
