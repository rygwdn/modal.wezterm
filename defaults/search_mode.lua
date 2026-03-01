local wezterm = require("wezterm")
local modal = wezterm.plugin.require("https://github.com/MLFlexer/modal.wezterm")

---Create status text with hints
---@param hint_icons {left_seperator: string, key_hint_seperator: string, mod_seperator: string}
---@param hint_colors {key_hint_seperator: string, key: string, hint: string, bg: string, left_bg: string}
---@param mode_colors {bg: string, fg: string}
---@return string
local function get_hint_status_text(hint_icons, hint_colors, mode_colors)
	return wezterm.format({
		{ Foreground = { Color = hint_colors.bg } },
		{ Background = { Color = hint_colors.left_bg } },
		{ Text = hint_icons.left_seperator },
		{ Background = { Color = hint_colors.bg } },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "CTRL" },
		{ Text = hint_icons.mod_seperator },
		{ Text = "p/n, 󰓢 : " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Prev/Next result" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "CTRL" },
		{ Text = hint_icons.mod_seperator },
		{ Text = "r: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Cycle match type" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "CTRL" },
		{ Text = hint_icons.mod_seperator },
		{ Text = "u: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Clear search" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "Enter: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Accep pattern" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "Esc: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "End search" },
		-- ...
		{ Attribute = { Intensity = "Bold" } },
		{ Foreground = { Color = mode_colors.bg } },
		{ Text = hint_icons.left_seperator },
		{ Foreground = { Color = mode_colors.fg } },
		{ Background = { Color = mode_colors.bg } },
		{ Text = "Search  " },
	})
end

---Create mode status text
---@param bg string
---@param fg string
---@param left_seperator string
---@return string
local function get_mode_status_text(left_seperator, bg, fg)
	return wezterm.format({
		{ Attribute = { Intensity = "Bold" } },
		{ Foreground = { Color = bg } },
		{ Text = left_seperator },
		{ Foreground = { Color = fg } },
		{ Background = { Color = bg } },
		{ Text = "Search  " },
	})
end

local function make_exit_search(mode_name)
	return wezterm.action_callback(function(window, pane)
		wezterm.GLOBAL.search_mode = false
		window:perform_action(modal.exit_mode(mode_name), pane)
		window:perform_action(modal.activate_mode("copy_mode"), pane)
	end)
end

-- Build a search key table for a given direction.
-- forward=true  -> n=NextMatch, N=PriorMatch  (/ search)
-- forward=false -> n=PriorMatch, N=NextMatch  (? search)
local function make_search_key_table(forward)
	local mode_name = forward and "search_mode_forward" or "search_mode_backward"
	local next_action = forward
		and wezterm.action.CopyMode("NextMatch")
		or  wezterm.action.CopyMode("PriorMatch")
	local prev_action = forward
		and wezterm.action.CopyMode("PriorMatch")
		or  wezterm.action.CopyMode("NextMatch")
	local exit_search = make_exit_search(mode_name)

	return {
		{
			key = "Enter",
			mods = "NONE",
			action = wezterm.action.Multiple({
				wezterm.action_callback(function(window, pane)
					wezterm.emit("modal.enter", "copy_mode", window, pane)
				end),
				wezterm.action.CopyMode("AcceptPattern"),
			}),
		},
		{ key = "Escape", action = exit_search },
		{ key = "c", mods = "CTRL", action = exit_search },
		{ key = "n", mods = "NONE", action = next_action },
		{ key = "N", mods = "SHIFT", action = prev_action },
		{ key = "n", mods = "CTRL", action = wezterm.action.CopyMode("NextMatch") },
		{ key = "p", mods = "CTRL", action = wezterm.action.CopyMode("PriorMatch") },
		{ key = "r", mods = "CTRL", action = wezterm.action.CopyMode("CycleMatchType") },
		{ key = "u", mods = "CTRL", action = wezterm.action.CopyMode("ClearPattern") },
		{ key = "PageUp",    mods = "NONE", action = wezterm.action.CopyMode("PriorMatchPage") },
		{ key = "PageDown",  mods = "NONE", action = wezterm.action.CopyMode("NextMatchPage") },
		{ key = "UpArrow",   mods = "NONE", action = wezterm.action.CopyMode("PriorMatch") },
		{ key = "DownArrow", mods = "NONE", action = wezterm.action.CopyMode("NextMatch") },
	}
end

return {
	get_mode_status_text = get_mode_status_text,
	get_hint_status_text = get_hint_status_text,
	key_table_forward  = make_search_key_table(true),
	key_table_backward = make_search_key_table(false),
}
