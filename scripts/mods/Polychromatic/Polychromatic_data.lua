local mod = get_mod("Polychromatic")

local SETS = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/sets")

local MODE_OPTIONS = {
	{ text = "mode_stock", value = "stock", show_widgets = {} },
	{ text = "mode_custom", value = "custom", show_widgets = { 1, 2 } },
	{ text = "mode_rainbow", value = "rainbow", show_widgets = { 2 } },
	{ text = "mode_hidden", value = "hidden", show_widgets = {} },
}

local DEFAULT_COLOURS = {
	mine = { 255, 0, 255, 64 },
	team = { 255, 64, 160, 255 },
	enemy = { 255, 255, 235, 0 },
}

local NO_RAINBOW_SETS = { sniper = true }

local function mode_options(set_id)
	local options = {}

	for i = 1, #MODE_OPTIONS do
		local option = MODE_OPTIONS[i]

		if option.value ~= "rainbow" or not NO_RAINBOW_SETS[set_id] then
			options[#options + 1] = table.clone(option)
		end
	end

	return options
end

local function category_widget(set_id, category)
	local prefix = set_id .. "_" .. category .. "_"

	if NO_RAINBOW_SETS[set_id] and mod:get(prefix .. "mode") == "rainbow" then
		mod:set(prefix .. "mode", "custom")
	end

	return {
		setting_id = prefix .. "show",
		type = "checkbox",
		default_value = true,
		sub_widgets = {
			{
				setting_id = prefix .. "mode",
				type = "dropdown",
				default_value = "stock",
				options = mode_options(set_id),
				sub_widgets = {
					{ setting_id = prefix .. "colour", type = "color", default_value = table.clone(DEFAULT_COLOURS[category]), has_alpha = false },
					{ setting_id = prefix .. "brightness", type = "numeric", default_value = 8, range = { 1, 15 }, decimals_number = 0 },
				},
			},
		},
	}
end

local SOURCE_SELECTOR_ID = "source_selector"
local NO_SOURCE = "none"

local set_groups = {}
local selector_options = {
	{ text = "select_source", value = NO_SOURCE, show_widgets = {} },
}

for i = 1, #SETS do
	local set = SETS[i]
	local group_id = set.id .. "_group"
	local sub_widgets = {}

	for j = 1, #set.categories do
		sub_widgets[#sub_widgets + 1] = category_widget(set.id, set.categories[j])
	end

	if set.id == "staff" then
		sub_widgets[#sub_widgets + 1] = { setting_id = "soulblaze", type = "checkbox", default_value = true }
	elseif set.id == "flamer" then
		sub_widgets[#sub_widgets + 1] = { setting_id = "flamer_burn", type = "checkbox", default_value = true }
	elseif set.id == "skull" then
		sub_widgets[#sub_widgets + 1] = { setting_id = "skull_burn", type = "checkbox", default_value = true }
	end

	set_groups[i] = { setting_id = group_id, type = "group", sub_widgets = sub_widgets }
	selector_options[i + 1] = { text = group_id, value = group_id, show_widgets = { i } }
end

local stored_source = mod:get(SOURCE_SELECTOR_ID)

if stored_source ~= nil then
	local known = false

	for i = 1, #selector_options do
		if selector_options[i].value == stored_source then
			known = true

			break
		end
	end

	if not known then
		mod:set(SOURCE_SELECTOR_ID, NO_SOURCE)
	end
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = SOURCE_SELECTOR_ID,
				type = "dropdown",
				default_value = NO_SOURCE,
				options = selector_options,
				sub_widgets = set_groups,
			},
			{ setting_id = "debug_logging", type = "checkbox", default_value = false },
		},
	},
}
