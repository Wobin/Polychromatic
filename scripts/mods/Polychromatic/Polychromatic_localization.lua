local redshift = get_mod("Redshift")
local redshift_active = redshift ~= nil and redshift:is_enabled()
local SNIPER_TITLE_REDSHIFT = "Enemy sniper laser - [Redshift is handling this]"

local polychromatic = get_mod("Polychromatic")
local module_list = polychromatic:io_dofile("Polychromatic/scripts/mods/Polychromatic/module_list")
local registry = module_list.registry(polychromatic, true)
local SOURCES = registry.sources

local SKIP_REASONS = {
	api_old = "made for an earlier version of Polychromatic: download the current version of this module",
}

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

		lines[#lines + 1] = ""
		lines[#lines + 1] = "The state of each module's effect package is reported by the /poly_check command."
	end

	if #registry.skipped > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Not loaded:"

		for _, entry in ipairs(registry.skipped) do
			local reason = SKIP_REASONS[entry.kind] or entry.reason

			lines[#lines + 1] = escape(tostring(entry.id) .. " (" .. tostring(reason) .. ")")
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
	effect_packages_enabled = { en = "Load effect packages" },
	effect_packages_enabled_description = { en = "Loads the recoloured effect copies of every installed module. Nothing is written to the game folder. Untick to use the game's own effects.\n\n" .. modules_detail() },
	legacy_install_removed = { en = "Polychromatic: the previous version's install was removed from the game folder." },
	legacy_install_failed = { en = "Polychromatic: the previous version's install could not be removed. The details are in the console log." },
	legacy_install_timed_out = { en = "Polychromatic: removing the previous version's install did not finish in time. The details are in the console log." },
	legacy_reason_dll_old = { en = "Polychromatic: the previous version's install could not be checked, because the loaded asset redirect library is older than this version needs." },
	modules_added = { en = "Polychromatic: module added: %s" },
	modules_removed = { en = "Polychromatic: module removed: %s" },
	modules_changed_refresh = { en = "Polychromatic: module updated: %s. Its effects refresh at the next mission or hub load." },
	host_failed = { en = "Polychromatic: %s effects stay as the game draws them (%s)" },
	hosts_failed = { en = "Polychromatic: effects stay as the game draws them (%s)" },
	host_reason_in_use = { en = "the game has loaded its host package" },
	host_reason_displaced = { en = "another mod replaces the same file" },
	host_reason_refused = { en = "the asset redirect library refused the file" },
	host_reason_restart_required = { en = "the game opened the file before it could be replaced" },
	host_reason_failed = { en = "the effect package could not be composed" },
	host_reason_unassigned = { en = "no host is assigned to this module" },
	host_reason_stream = { en = "a data file for this module could not be replaced (%s)" },
	host_reason_no_native = { en = "the asset redirect library is not loaded" },
	host_reason_dll_old = { en = "the loaded asset redirect library is older than effect packages need" },
	host_reason_busy = { en = "the asset redirect library stayed busy" },
	host_reason_timeout = { en = "composing the effect package did not finish in time" },
	host_reason_unavailable = { en = "the asset redirect library reported no state for the file" },
	host_reason_duplicate_stream = { en = "another module provides the same data file" },
	poly_check_summary = { en = "Polychromatic %s: %s modules, hosts: %s active, %s other, redirect library %s, redirects %s of %s served, %s effects seen. Details are in the console log." },
	poly_check_library_loaded = { en = "loaded" },
	poly_check_library_missing = { en = "not loaded" },
	poly_check_no_native = { en = "The asset redirect library (asset-redirect.dll) did not load, so only las beams can be recoloured. Check that the file is still in the mod's bin folder and was not quarantined by antivirus. The path tried and the reason are in the console log." },
	poly_check_refused = { en = "%s redirects were refused, most likely because a game update changed the files they replace." },
	debug_logging = { en = "Debug logging" },
	debug_logging_description = { en = "Writes Polychromatic's setup details to the console log: which patched files are served at launch, a full /poly_check report at launch, and a line each time a patched effect package loads. Turning it on also writes a /poly_check report straight away (once per game session)." },
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
