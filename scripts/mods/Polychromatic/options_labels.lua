return function(mod, deps)
	local SNIPER_GROUP_ID = "sniper_group"
	local OPTIONS_VIEW = "dmf_options_view"

	local _sniper_group_title = mod:localize(SNIPER_GROUP_ID)

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

	if deps.has_sniper then
		mod:hook_safe(get_mod("DMF"), "set_mod_state", function(target_mod)
			if target_mod and target_mod.get_name and target_mod:get_name() == "Redshift" then
				refresh_sniper_group_title()
			end
		end)
	end
end
