local redshift = get_mod("Redshift")
local redshift_active = redshift ~= nil and redshift:is_enabled()
local SNIPER_TITLE_REDSHIFT = "Enemy sniper laser - [Redshift is handling this]"

local polychromatic = get_mod("Polychromatic")
local module_list = polychromatic:io_dofile("Polychromatic/scripts/mods/Polychromatic/module_list")
local registry = module_list.registry(polychromatic, true)
local SOURCES = registry.sources

local function escape(text)
	return (tostring(text):gsub("%%", "%%%%"))
end

local function plural(count, word)
	return count .. " " .. word .. (count == 1 and "" or "s")
end

local function general_title()
	local loaded = #registry.modules
	local skipped = #registry.skipped
	local title

	if loaded == 0 then
		title = "General (no modules installed"
	else
		title = "General (" .. plural(loaded, "module")
	end

	if skipped > 0 then
		title = title .. (loaded == 0 and "; " or ", ") .. skipped .. " not loaded"
	end

	return title .. ")"
end

local function modules_detail()
	local lines = {}

	if #registry.modules == 0 then
		local homepage = polychromatic.get_metadata and polychromatic:get_metadata("homepage")

		lines[#lines + 1] = "No modules installed. Download module zips from the Polychromatic page on Nexus Mods"
			.. (homepage and (" (" .. escape(homepage) .. ")") or "")
			.. " and unzip them into the game's mods folder."
	else
		lines[#lines + 1] = "Loaded modules:"

		for _, manifest in ipairs(registry.modules) do
			lines[#lines + 1] = escape((manifest.label or manifest.id) .. " " .. tostring(manifest.version))
		end
	end

	if #registry.skipped > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Not loaded:"

		for _, entry in ipairs(registry.skipped) do
			lines[#lines + 1] = escape(tostring(entry.id) .. " (" .. tostring(entry.reason) .. ")")
		end
	end

	return table.concat(lines, "\n")
end

local SHOW_LABELS = {
	mine = "Show my fire",
	team = "Show team fire",
	enemy = "Show enemy fire",
}

local localization = {
	mod_name = { en = "Polychromatic" },
	mod_description = { en = "Recolours or hides weapon and Psyker effects (flame, las, plasma, lightning and warp powers), separately for your own and your team's, plus the enemy sniper laser and exploding barrels." },
	restart_required = { en = "Polychromatic: flame files changed while the game was running. Restart the game for them to take effect." },
	game_format_changed = { en = "Polychromatic: this game update changed the effect file format. Fire and las colours stay stock until Polychromatic is updated." },
	game_format_unknown = { en = "Polychromatic: could not read the game's effect file format. Fire and las colours stay stock this session." },
	sources_heading = { en = "Sources" },
	general_heading = { en = general_title() },
	effect_packages = { en = "Effect packages" },
	effect_packages_button = { en = "Install or remove" },
	effect_packages_installed = { en = "Effect packages: installed" },
	effect_packages_removing = { en = "Effect packages: removed from next start" },
	effect_packages_installing = { en = "Effect packages: installed from next start" },
	effect_packages_absent = { en = "Effect packages: not installed" },
	effect_packages_checking = { en = "Effect packages: checking" },
	effect_packages_button_checking = { en = "Checking" },
	effect_packages_button_installed = { en = "Remove" },
	effect_packages_button_removing = { en = "Reinstall" },
	effect_packages_button_installing = { en = "Remove" },
	effect_packages_button_absent = { en = "Install" },
	effect_packages_description = { en = "Polychromatic registers its extra effect copies (barrel fire and others) as game packages the first time it loads, keeping a backup of the one game file it changes. Hold this to remove them and put the game's own files back; hold it again to reinstall. Either change takes effect from the next game start.\n\n" .. modules_detail() },
	packages_installed = { en = "Polychromatic: effect packages installed. Restart the game to use them." },
	packages_removed = { en = "Polychromatic: effect packages removed. The game uses its own files from the next start." },
	packages_remove_next_launch = { en = "Polychromatic: effect packages are in use this session. They will be removed when the game next starts." },
	packages_failed = { en = "Polychromatic: could not install the effect packages; built-in colours are used" },
	packages_nothing_to_install = { en = "Polychromatic: no modules installed, so there are no effect packages to install." },
	modules_changed = { en = "Polychromatic: modules changed" },
	restart_to_apply = { en = "Restart to apply." },
	modules_none = { en = "Polychromatic: no modules installed; effect packages removed from the next start." },
	debug_logging = { en = "Debug logging" },
	debug_logging_description = { en = "Writes Polychromatic's setup details to the console log: which patched files are served at launch, a full /poly_check report at launch, and a line each time a patched effect package loads. Turning it on also writes a /poly_check report straight away (once per game session); restart the game to capture the launch details too." },
	poly_check_description = { en = "Polychromatic: report the setup state to the console log for troubleshooting." },
	flamer_burn = { en = "Burning enemies follow these settings" },
	skull_burn = { en = "Burning enemies follow these settings" },
	skull_burn_description = { en = "Enemies the servo-skull sets alight burn in the skull's colour, taken at the moment they catch fire, and glow in it as they char. The skull's own colour, saturation and brightness always apply, whatever the flamer is set to (restart after changing saturation or brightness). The main flame and the two brightest stack layers recolour; the smoke and embers stay stock." },
	flamer_burn_description = { en = "Enemies set alight by a flamer burn in that flamer's colour, taken at the moment they catch fire, and glow in it as they char. The main flame and the two brightest stack layers recolour; the smoke and embers stay stock." },
	shield_mine_damage_gate = { en = "Change colour when my shield is damaged" },
	shield_mine_damage_gate_description = { en = "When one of your shields falls below the set percentage of its health it switches to your damaged colour, even when Colour is Base." },
	shield_team_damage_gate = { en = "Change colour when a team shield is damaged" },
	shield_team_damage_gate_description = { en = "When a teammate's shield falls below the set percentage of its health it switches to the team damaged colour, even when Colour is Base." },
	shield_mine_damage_threshold = { en = "Damaged below (%%)" },
	shield_team_damage_threshold = { en = "Damaged below (%%)" },
	shield_mine_damaged_colour = { en = "Damaged colour" },
	shield_team_damaged_colour = { en = "Damaged colour" },
	soulblaze = { en = "Soulblaze glow follows these settings" },
	soulblaze_description = { en = "Enemies set alight by your or your team's Inferno staff glow and burn in that staff's colour, taken at the moment they catch fire (so rainbow gives each burn its own colour). The flames use the nearest of 12 hues, with brightness and saturation taken from your own staff setting when the game starts, or your team setting if yours is off (restart after changing them). Every enemy except the daemonhost; a few small decals on some enemies do not glow." },
	source_selector = { en = "Source" },
	source_selector_description = { en = "Pick which effect to set up. Only that source's options are shown." },
	select_source = { en = "Select a source" },
	mode_stock = { en = "Base" },
	mode_custom = { en = "Set colour" },
	mode_rainbow = { en = "Rainbow" },
	mode_hidden = { en = "Hidden" },
}

local function module_widget_labels(widgets)
	for _, widget in ipairs(type(widgets) == "table" and widgets or {}) do
		local id = type(widget) == "table" and widget.setting_id

		if type(id) == "string" then
			if localization[id] == nil and type(widget.label) == "string" then
				localization[id] = { en = escape(widget.label) }
			end

			if localization[id .. "_description"] == nil and type(widget.description) == "string" then
				localization[id .. "_description"] = { en = escape(widget.description) }
			end

			module_widget_labels(widget.sub_widgets)
		end
	end
end

for i = 1, #SOURCES do
	module_widget_labels(SOURCES[i].widgets)
end

for i = 1, #SOURCES do
	local set = SOURCES[i]
	local show_labels = SHOW_LABELS

	local title = escape(set.label)

	if set.id == "sniper" then
		localization.sniper_group_plain = { en = escape(set.label) }
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
			show_description = escape(set.description) .. "\n\n" .. show_description
		end

		localization[prefix .. "show"] = { en = set.show_label and escape(set.show_label) or show_labels[category] }
		localization[prefix .. "show_description"] = { en = show_description }
		localization[prefix .. "mode"] = { en = "Colour" }
		localization[prefix .. "colour"] = { en = "Set colour" }
		localization[prefix .. "brightness"] = { en = "Brightness (8 = normal)" }
		localization[prefix .. "brightness_description"] = { en = "Overall brightness. 8 matches the stock effect, 1 is the faintest, 15 the strongest." }
	end
end

return localization
