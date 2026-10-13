local mod = get_mod("Polychromatic")

local module_list = mod:io_dofile("Polychromatic/scripts/mods/Polychromatic/module_list")
local registry = module_list.registry(mod)
local SOURCES = registry.sources

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

local function mode_options(source)
	local options = {}

	for i = 1, #MODE_OPTIONS do
		local option = MODE_OPTIONS[i]
		local excluded = option.value == "rainbow" and source.no_rainbow or option.value == "hidden" and source.no_hidden

		if not excluded then
			options[#options + 1] = table.clone(option)
		end
	end

	return options
end

local function category_widget(source, category)
	local prefix = source.id .. "_" .. category .. "_"

	if source.no_rainbow and mod:get(prefix .. "mode") == "rainbow" then
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
				options = mode_options(source),
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

for _, category in ipairs({ "mine", "team" }) do
	for _, key in ipairs({ "show", "mode", "colour", "brightness" }) do
		local old_id = "force_staff_" .. category .. "_" .. key
		local value = mod:get(old_id)

		if value ~= nil then
			for _, set_id in ipairs({ "staff_trauma", "staff_voidstrike" }) do
				local new_id = set_id .. "_" .. category .. "_" .. key

				if mod:get(new_id) == nil then
					mod:set(new_id, type(value) == "table" and table.clone(value) or value)
				end
			end

			mod:set(old_id, nil)
		end
	end
end

local set_groups = {}
local selector_options = {
	{ text = "select_source", value = NO_SOURCE, show_widgets = {} },
}

for i = 1, #SOURCES do
	local source = SOURCES[i]
	local group_id = source.id .. "_group"
	local sub_widgets = {}

	for j = 1, #source.categories do
		sub_widgets[#sub_widgets + 1] = category_widget(source, source.categories[j])
	end

	for _, widget in ipairs(source.widgets or {}) do
		sub_widgets[#sub_widgets + 1] = table.clone(widget)
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

local widgets = {}

if #SOURCES > 0 then
	widgets[#widgets + 1] = {
		setting_id = "sources_heading",
		type = "group",
		sub_widgets = {
			{
				setting_id = SOURCE_SELECTOR_ID,
				type = "dropdown",
				default_value = NO_SOURCE,
				options = selector_options,
				sub_widgets = set_groups,
			},
		},
	}
end

widgets[#widgets + 1] = {
	setting_id = "general_heading",
	type = "group",
	sub_widgets = {
		{
			setting_id = "effect_packages",
			type = "button",
			button_text = "effect_packages_button",
			button_trigger = "held",
			function_name = "toggle_effect_packages",
		},
		{ setting_id = "debug_logging", type = "checkbox", default_value = false },
	},
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	allow_rehooking = true,
	options = {
		widgets = widgets,
	},
}
