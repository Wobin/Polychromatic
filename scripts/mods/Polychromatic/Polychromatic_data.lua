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

	local stored_mode = mod:get(prefix .. "mode")

	if source.no_rainbow and stored_mode == "rainbow" then
		mod:set(prefix .. "mode", "custom")
	elseif source.no_hidden and stored_mode == "hidden" then
		mod:set(prefix .. "mode", "stock")
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

local RENAMED_SETTINGS = {
	shield_damage_threshold = "shield_mine_damage_threshold",
}

for old_id, new_id in pairs(RENAMED_SETTINGS) do
	local value = mod:get(old_id)

	if value ~= nil then
		if mod:get(new_id) == nil then
			mod:set(new_id, value)
		end

		mod:set(old_id, nil)
	end
end

local function module_widget(widget)
	local copy = table.clone(widget)

	copy.label = nil
	copy.description = nil

	for i, sub_widget in ipairs(copy.sub_widgets or {}) do
		copy.sub_widgets[i] = module_widget(sub_widget)
	end

	return copy
end

local set_groups = {}
local selector_options = {
	{ text = "select_source", value = NO_SOURCE, show_widgets = {} },
}

local glows_of = {}
local source_ids = {}

for i = 1, #SOURCES do
	source_ids[SOURCES[i].id] = true
end

for i = 1, #SOURCES do
	local source = SOURCES[i]

	if source.glow_of and source_ids[source.glow_of] then
		local list = glows_of[source.glow_of] or {}

		list[#list + 1] = source
		glows_of[source.glow_of] = list
	end
end

local function glow_widget(source)
	local own = { setting_id = source.id .. "_own", type = "checkbox", default_value = false, sub_widgets = {} }

	for j = 1, #source.categories do
		own.sub_widgets[#own.sub_widgets + 1] = category_widget(source, source.categories[j])
	end

	return own
end

for i = 1, #SOURCES do
	local source = SOURCES[i]

	if not (source.glow_of and source_ids[source.glow_of]) then
		local group_id = source.id .. "_group"
		local sub_widgets = {}

		for j = 1, #source.categories do
			sub_widgets[#sub_widgets + 1] = category_widget(source, source.categories[j])
		end

		for _, glow in ipairs(glows_of[source.id] or {}) do
			sub_widgets[#sub_widgets + 1] = glow_widget(glow)
		end

		for _, widget in ipairs(source.widgets or {}) do
			sub_widgets[#sub_widgets + 1] = module_widget(widget)
		end

		set_groups[#set_groups + 1] = { setting_id = group_id, type = "group", sub_widgets = sub_widgets }
		selector_options[#selector_options + 1] = { text = group_id, value = group_id, show_widgets = { #set_groups } }
	end
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
		{ setting_id = "effect_packages_enabled", type = "checkbox", default_value = true },
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
