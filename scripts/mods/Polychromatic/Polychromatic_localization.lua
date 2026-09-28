local redshift = get_mod("Redshift")
local redshift_active = redshift ~= nil and redshift:is_enabled()
local SNIPER_TITLE_REDSHIFT = "Enemy Sniper Laser - [Redshift Is Handling This]"

local SETS = {
	{ id = "staff", categories = { "mine", "team" }, label = "Inferno staff", description = "Psyker Inferno staff streams and their wall impacts." },
	{ id = "flamer", categories = { "mine", "team" }, label = "Flamer", description = "Zealot flamer streams and wall impacts." },
	{ id = "skull", categories = { "mine", "team" }, label = "Servo-skull flamer", description = "The Skitarii companion servo-skull flamer." },
	{ id = "las", categories = { "mine", "team" }, label = "Las weapons", description = "Las beams, muzzle flashes and impacts for lasguns, laspistols and the Helbore." },
	{ id = "plasma", categories = { "mine", "team" }, label = "Plasma gun", description = "Plasma gun muzzle, charge, overcharge vents, beams, impacts and charged explosions." },
	{ id = "greatsword", categories = { "mine", "team" }, label = "Force greatsword", description = "Psyker two-hand force sword: charge, activation, the warp wisps at the fingertips, blocks, parries and the push." },
	{ id = "sniper", categories = { "enemy" }, label = "Enemy sniper laser", description = "The Scab Sniper targeting laser and its shot. Stock red is easy to lose against warm backgrounds." },
}

local SHOW_LABELS = {
	mine = "Show my fire",
	team = "Show team fire",
	enemy = "Show enemy fire",
}

local localization = {
	mod_name = { en = "Polychromatic" },
	mod_description = { en = "Recolours or hides fire and las effects, separately for your own and your team's fire, plus the enemy sniper laser." },
	restart_required = { en = "Polychromatic: flame files changed while the game was running. Restart the game for them to take effect." },
	debug_logging = { en = "Debug logging" },
	debug_logging_description = { en = "Writes Polychromatic's setup details to the console log: which patched files are served at launch, a full /poly_check report at launch, and a line each time a patched effect package loads. Turning it on also writes a /poly_check report straight away (once per game session); restart the game to capture the launch details too." },
	poly_check_description = { en = "Polychromatic: report the setup state to the console log for troubleshooting." },
	flamer_burn = { en = "Burning enemies follow these settings" },
	skull_burn = { en = "Burning enemies follow these settings" },
	skull_burn_description = { en = "Enemies the servo-skull sets alight burn in the skull's colour, taken at the moment they catch fire, and glow in it as they char. Saturation and brightness come from the flamer setting when that source is on, otherwise from this one (restart after changing them). The main flame and the two brightest stack layers recolour; the smoke and embers stay stock." },
	flamer_burn_description = { en = "Enemies set alight by a flamer burn in that flamer's colour, taken at the moment they catch fire, and glow in it as they char. The main flame and the two brightest stack layers recolour; the smoke and embers stay stock." },
	soulblaze = { en = "Soulblaze glow follows these settings" },
	soulblaze_description = { en = "Enemies set alight by your or your team's Inferno staff glow and burn in that staff's colour, taken at the moment they catch fire (so rainbow gives each burn its own colour). The flames use the nearest of 12 hues, with brightness and saturation taken from your own staff setting when the game starts, or your team setting if yours is off (restart after changing them). Every enemy except the daemonhost; a few small decals on some enemies do not glow." },
	source_selector = { en = "Source" },
	source_selector_description = { en = "Pick which fire or las effect to set up. Only that source's options are shown." },
	select_source = { en = "Select a source" },
	mode_stock = { en = "Base" },
	mode_custom = { en = "Set colour" },
	mode_rainbow = { en = "Rainbow" },
	mode_hidden = { en = "Hidden" },
}

for i = 1, #SETS do
	local set = SETS[i]
	local show_labels = SHOW_LABELS

	local title = set.label

	if set.id == "sniper" then
		localization.sniper_group_plain = { en = set.label }
		localization.sniper_group_redshift = { en = SNIPER_TITLE_REDSHIFT }

		if redshift_active then
			title = SNIPER_TITLE_REDSHIFT
		end
	end

	localization[set.id .. "_group"] = { en = title }

	for j = 1, #set.categories do
		local category = set.categories[j]
		local prefix = set.id .. "_" .. category .. "_"
		local show_description = "Untick to leave this fire exactly as the game draws it. To remove it instead, set Colour to Hidden."

		if j == 1 then
			show_description = set.description .. "\n\n" .. show_description
		end

		localization[prefix .. "show"] = { en = show_labels[category] }
		localization[prefix .. "show_description"] = { en = show_description }
		localization[prefix .. "mode"] = { en = "Colour" }
		localization[prefix .. "colour"] = { en = "Set colour" }
		localization[prefix .. "brightness"] = { en = "Brightness (8 = normal)" }
		localization[prefix .. "brightness_description"] = { en = "Overall brightness. 8 matches the stock effect, 1 is the faintest, 15 the strongest." }
	end
end

return localization
