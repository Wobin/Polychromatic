return function(mod, deps)
	local SNIPER_GROUP_ID = "sniper_group"
	local PACKAGES_SETTING = "effect_packages"
	local OPTIONS_VIEW = "dmf_options_view"

	local _sniper_group_title = mod:localize(SNIPER_GROUP_ID)
	local labels = {}

	local function strip_markup(text)
		if type(text) ~= "string" then
			return nil
		end

		return (text:gsub("{#.-}", ""))
	end

	local function set_group_data_title(widgets, title)
		for i = 1, #widgets do
			local data = widgets[i]

			if type(data) == "table" then
				if type(data.options) == "table" then
					for j = 1, #data.options do
						local option = data.options[j]

						if type(option) == "table" and option.value == SNIPER_GROUP_ID then
							option.text = title
							option.display_name = title
						end
					end
				end

				if data.setting_id == SNIPER_GROUP_ID then
					data.title = title
					data.display_name = title

					return true
				end

				if type(data.sub_widgets) == "table" and set_group_data_title(data.sub_widgets, title) then
					return true
				end
			end
		end

		return false
	end

	local function set_open_view_title(old_title, title)
		local ui_manager = Managers.ui
		local view = ui_manager and ui_manager:view_instance(OPTIONS_VIEW)
		local categories = view and view._settings_category_widgets

		if not categories then
			return
		end

		local old_clean = strip_markup(old_title)

		for _, widgets in pairs(categories) do
			for i = 1, #widgets do
				local widget = widgets[i] and widgets[i].widget
				local content = widget and widget.content

				if content and strip_markup(content.text) == old_clean then
					if content.entry then
						content.entry.display_name = title
						content.entry.title = title
					end

					content.text = title
					widget.dirty = true

					return
				end
			end
		end
	end

	local function refresh_sniper_group_title()
		local title = mod:localize(deps.redshift_owns_sniper() and "sniper_group_redshift" or "sniper_group_plain")

		if title == _sniper_group_title then
			return
		end

		local old_title = _sniper_group_title
		local dmf = get_mod("DMF")
		local all_widgets = dmf and dmf.options_widgets_data

		_sniper_group_title = title

		if type(all_widgets) == "table" then
			local name = mod:get_name()

			for i = 1, #all_widgets do
				local mod_widgets = all_widgets[i]

				if type(mod_widgets) == "table" and mod_widgets[1] and mod_widgets[1].mod_name == name then
					set_group_data_title(mod_widgets, title)

					break
				end
			end
		end

		set_open_view_title(old_title, title)
	end

	mod:hook_safe(get_mod("DMF"), "set_mod_state", function(target_mod)
		if target_mod and target_mod.get_name and target_mod:get_name() == "Redshift" then
			refresh_sniper_group_title()
		end
	end)

	local function find_widget(list, target)
		if type(list) ~= "table" then
			return nil
		end

		for _, widget in ipairs(list) do
			if type(widget) == "table" then
				if widget.setting_id == target then
					return widget
				end

				local found = find_widget(widget.sub_widgets, target) or find_widget(widget.widgets, target)

				if found then
					return found
				end
			end
		end

		return nil
	end

	local function live_package_content()
		local ui = Managers.ui

		if not ui or not ui.view_active or not ui:view_active(OPTIONS_VIEW) then
			return nil
		end

		local view = ui:view_instance(OPTIONS_VIEW)
		local list = view and rawget(view, "_settings_content_widgets")

		if type(list) ~= "table" then
			return nil
		end

		for i = 1, #list do
			local content = list[i] and rawget(list[i], "content")
			local entry = content and rawget(content, "entry")

			if entry and rawget(entry, "setting_id") == PACKAGES_SETTING then
				return content
			end
		end

		return nil
	end

	function labels.sync_package_label()
		local dmf = get_mod("DMF")
		local key = deps.package_label_key()
		local title = mod:localize("effect_packages_" .. key)
		local button = mod:localize("effect_packages_button_" .. key)
		local widget = nil

		for _, entry in ipairs(dmf and dmf.options_widgets_data or {}) do
			widget = widget or find_widget(entry, PACKAGES_SETTING)
		end

		if widget then
			widget.title = title
			widget.button_text = button
			widget.tooltip = title .. "\n" .. mod:localize("effect_packages_description")
		end

		local live = live_package_content()

		if live then
			live.text = title
			live.button_text = button
			live.original_button_text = button
		end
	end

	return labels
end
