local wezterm = require("wezterm")
local modal = require("modal")

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
		{ Text = "Shift,CTRL,ALT?" },
		{ Text = hint_icons.mod_seperator },
		{ Text = "v: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Visual mode" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "/: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Search mode" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "p/n: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Prev/Next result" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "s/S: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Semantic jump" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "y: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Copy and exit" },
		{ Foreground = { Color = hint_colors.key_hint_seperator } },
		{ Text = hint_icons.key_hint_seperator },
		-- ...
		{ Foreground = { Color = hint_colors.key } },
		{ Text = "hjkl: " },
		{ Foreground = { Color = hint_colors.hint } },
		{ Text = "Move " },
		-- ...
		{ Attribute = { Intensity = "Bold" } },
		{ Foreground = { Color = mode_colors.bg } },
		{ Text = hint_icons.left_seperator },
		{ Foreground = { Color = mode_colors.fg } },
		{ Background = { Color = mode_colors.bg } },
		{ Text = "Copy  " },
	})
end

-- Probe whether the token motion actions are available in this wezterm build.
local has_token_motions = pcall(function()
	local _ = wezterm.action.CopyMode("MoveForwardToken")
end)

-- Activate search in a given direction.
-- We store the direction in wezterm.GLOBAL so that n/N in copy mode
-- can use the correct NextMatch/PriorMatch action after search ends.
local function activate_search(forward)
	return wezterm.action_callback(function(window, pane)
		wezterm.GLOBAL.search_forward = forward
		window:perform_action(
			wezterm.action.Multiple({
				wezterm.action.Search({ CaseSensitiveString = "" }),
				wezterm.action_callback(function(w, p)
					wezterm.emit("modal.enter", "search_mode", w, p)
				end),
			}),
			pane
		)
	end)
end

-- Bracket chord tables for [/] zone navigation
local bracket_back_table = {
	{ key = "[", action = wezterm.action.CopyMode("MoveBackwardSemanticZone") },
	{ key = "o", action = wezterm.action.CopyMode({ MoveBackwardZoneOfType = "Output" }) },
	{ key = "p", action = wezterm.action.CopyMode({ MoveBackwardZoneOfType = "Prompt" }) },
	{ key = "i", action = wezterm.action.CopyMode({ MoveBackwardZoneOfType = "Input" }) },
}

local bracket_forward_table = {
	{ key = "]", action = wezterm.action.CopyMode("MoveForwardSemanticZone") },
	{ key = "o", action = wezterm.action.CopyMode({ MoveForwardZoneOfType = "Output" }) },
	{ key = "p", action = wezterm.action.CopyMode({ MoveForwardZoneOfType = "Prompt" }) },
	{ key = "i", action = wezterm.action.CopyMode({ MoveForwardZoneOfType = "Input" }) },
}

local key_table = {
		-- Cancel the mode by pressing escape
		{
			key = "Escape",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.visual_mode then
					wezterm.emit("modal.enter", "copy_mode", window, pane)
					window:perform_action(
						wezterm.action.CopyMode({ SetSelectionMode = wezterm.GLOBAL.visual_mode }),
						pane
					)
					wezterm.GLOBAL.visual_mode = nil
				else
					wezterm.GLOBAL.search_forward = nil
					window:perform_action(wezterm.action.CopyMode("ClearPattern"), pane)
					window:perform_action(modal.exit_mode("copy_mode"), pane)
				end
			end),
		},
		{
			key = "c",
			mods = "CTRL",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.visual_mode then
					wezterm.emit("modal.enter", "copy_mode", window, pane)
					window:perform_action(
						wezterm.action.CopyMode({ SetSelectionMode = wezterm.GLOBAL.visual_mode }),
						pane
					)
					wezterm.GLOBAL.visual_mode = nil
				else
					wezterm.GLOBAL.search_forward = nil
					window:perform_action(wezterm.action.CopyMode("ClearPattern"), pane)
					window:perform_action(modal.exit_mode("copy_mode"), pane)
				end
			end),
		},

		-- Move to start and end of line
		{ key = "Enter", action = wezterm.action.CopyMode("MoveToStartOfNextLine") },
		{ key = "$", action = wezterm.action.CopyMode("MoveToEndOfLineContent") },
		{ key = "0", action = wezterm.action.CopyMode("MoveToStartOfLine") },
		{ key = "^", action = wezterm.action.CopyMode("MoveToStartOfLineContent") },

		{ key = "End", action = wezterm.action.CopyMode("MoveToEndOfLineContent") },
		{ key = "Home", action = wezterm.action.CopyMode("MoveToStartOfLine") },

		-- Move to scrollback positions
		{ key = "g", action = wezterm.action.ActivateKeyTable({
			name = "copy_mode_g_prefix",
			one_shot = true,
			timeout_milliseconds = 1000,
		}) },
		{ key = "G", mods = "SHIFT", action = wezterm.action.CopyMode("MoveToScrollbackBottom") },
		{ key = "H", mods = "SHIFT", action = wezterm.action.CopyMode("MoveToViewportTop") },
		{ key = "L", mods = "SHIFT", action = wezterm.action.CopyMode("MoveToViewportBottom") },
		{ key = "M", mods = "SHIFT", action = wezterm.action.CopyMode("MoveToViewportMiddle") },

		-- Jump to other end of visual selection
		{ key = "o", action = wezterm.action.CopyMode("MoveToSelectionOtherEnd") },
		{ key = "O", mods = "SHIFT", action = wezterm.action.CopyMode("MoveToSelectionOtherEndHoriz") },

		-- Visual line mode
		{
			key = "v",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.visual_mode == "Cell" then
					wezterm.emit("modal.enter", "copy_mode", window, pane)
					window:perform_action(
						wezterm.action.CopyMode({ SetSelectionMode = wezterm.GLOBAL.visual_mode }),
						pane
					)
					wezterm.GLOBAL.visual_mode = nil
				else
					window:perform_action(
						wezterm.action.Multiple({
							wezterm.action.CopyMode({ SetSelectionMode = "Cell" }),
							wezterm.action_callback(function(_, _)
								wezterm.GLOBAL.visual_mode = "Cell"
								wezterm.emit("modal.enter", "Visual", window, pane)
							end),
						}),
						pane
					)
				end
			end),
		},
		{
			key = "V",
			mods = "SHIFT",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.visual_mode == "Line" then
					wezterm.emit("modal.enter", "copy_mode", window, pane)
					window:perform_action(
						wezterm.action.CopyMode({ SetSelectionMode = wezterm.GLOBAL.visual_mode }),
						pane
					)
					wezterm.GLOBAL.visual_mode = nil
				else
					window:perform_action(
						wezterm.action.Multiple({
							wezterm.action.CopyMode({ SetSelectionMode = "Line" }),
							wezterm.action_callback(function(_, _)
								wezterm.GLOBAL.visual_mode = "Line"
								wezterm.emit("modal.enter", "Visual", window, pane)
							end),
						}),
						pane
					)
				end
			end),
		},
		{
			key = "v",
			mods = "CTRL",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.visual_mode == "Block" then
					wezterm.emit("modal.enter", "copy_mode", window, pane)
					window:perform_action(
						wezterm.action.CopyMode({ SetSelectionMode = wezterm.GLOBAL.visual_mode }),
						pane
					)
					wezterm.GLOBAL.visual_mode = nil
				else
					window:perform_action(
						wezterm.action.Multiple({
							wezterm.action.CopyMode({ SetSelectionMode = "Block" }),
							wezterm.action_callback(function(_, _)
								wezterm.GLOBAL.visual_mode = "Block"
								wezterm.emit("modal.enter", "Visual", window, pane)
							end),
						}),
						pane
					)
				end
			end),
		},
		{
			key = "v",
			mods = "ALT",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.visual_mode == "SemanticZone" then
					wezterm.emit("modal.enter", "copy_mode", window, pane)
					window:perform_action(
						wezterm.action.CopyMode({ SetSelectionMode = wezterm.GLOBAL.visual_mode }),
						pane
					)
					wezterm.GLOBAL.visual_mode = nil
				else
					window:perform_action(
						wezterm.action.Multiple({
							wezterm.action.CopyMode({ SetSelectionMode = "SemanticZone" }),
							wezterm.action_callback(function(_, _)
								wezterm.GLOBAL.visual_mode = "SemanticZone"
								wezterm.emit("modal.enter", "Visual", window, pane)
							end),
						}),
						pane
					)
				end
			end),
		},

		-- Semantic zone navigation
		{
			key = "s",
			mods = "NONE",
			action = wezterm.action.CopyMode("MoveBackwardSemanticZone"),
		},
		{
			key = "S",
			mods = "SHIFT",
			action = wezterm.action.CopyMode("MoveForwardSemanticZone"),
		},

		-- Paragraph-style jumps between shell prompts (vim { and })
		{ key = "{", mods = "SHIFT", action = wezterm.action.CopyMode({ MoveBackwardZoneOfType = "Prompt" }) },
		{ key = "}", mods = "SHIFT", action = wezterm.action.CopyMode({ MoveForwardZoneOfType = "Prompt" }) },

		-- [ prefix: backward zone navigation chord
		{ key = "[", action = wezterm.action.ActivateKeyTable({
			name = "copy_mode_bracket_back",
			one_shot = true,
			timeout_milliseconds = 1000,
		}) },
		-- ] prefix: forward zone navigation chord
		{ key = "]", action = wezterm.action.ActivateKeyTable({
			name = "copy_mode_bracket_forward",
			one_shot = true,
			timeout_milliseconds = 1000,
		}) },

		-- Move by cell
		{ key = "h", action = wezterm.action.CopyMode("MoveLeft") },
		{ key = "j", action = wezterm.action.CopyMode("MoveDown") },
		{ key = "k", action = wezterm.action.CopyMode("MoveUp") },
		{ key = "l", action = wezterm.action.CopyMode("MoveRight") },
		{ key = "LeftArrow", action = wezterm.action.CopyMode("MoveLeft") },
		{ key = "RightArrow", action = wezterm.action.CopyMode("MoveRight") },
		{ key = "UpArrow", action = wezterm.action.CopyMode("MoveUp") },
		{ key = "DownArrow", action = wezterm.action.CopyMode("MoveDown") },

		-- Move by word (Unicode UAX#29 boundaries)
		{ key = "w", action = wezterm.action.CopyMode("MoveForwardWord") },
		{ key = "e", action = wezterm.action.CopyMode("MoveForwardWordEnd") },
		{ key = "b", action = wezterm.action.CopyMode("MoveBackwardWord") },
		{ key = "LeftArrow", mods = "CTRL", action = wezterm.action.CopyMode("MoveBackwardWord") },
		{ key = "RightArrow", mods = "CTRL", action = wezterm.action.CopyMode("MoveForwardWord") },

		-- Move by page
		{ key = "d", mods = "CTRL", action = wezterm.action.CopyMode({ MoveByPage = 0.5 }) },
		{
			key = "u",
			mods = "CTRL",
			action = wezterm.action.CopyMode({ MoveByPage = -0.5 }),
		},
		{ key = "PageUp", action = wezterm.action.CopyMode("PageUp") },
		{ key = "PageDown", action = wezterm.action.CopyMode("PageDown") },
		{ key = "b", mods = "CTRL", action = wezterm.action.CopyMode("PageUp") },
		{ key = "f", mods = "CTRL", action = wezterm.action.CopyMode("PageDown") },

		-- yank
		{
			key = "y",
			action = wezterm.action.Multiple({
				{ CopyTo = "ClipboardAndPrimarySelection" },
				wezterm.action.CopyMode("ClearSelectionMode"),
				wezterm.action.CopyMode("ClearPattern"),
				modal.exit_mode("copy_mode"),
			}),
		},
		{
			key = "Y",
			mods = "SHIFT",
			action = wezterm.action.Multiple({
				{ CopyTo = "ClipboardAndPrimarySelection" },
				wezterm.action.CopyMode("ClearSelectionMode"),
				wezterm.action.CopyMode("ClearPattern"),
				modal.exit_mode("copy_mode"),
				{ PasteFrom = "Clipboard" },
			}),
		},

		-- Search: / = forward, ? (Shift+/) = backward
		{
			key = "/",
			mods = "NONE",
			action = activate_search(true),
		},
		{
			key = "?",
			mods = "NONE",
			action = activate_search(false),
		},
		-- n/N respect search direction stored when / or ? was pressed
		{
			key = "n",
			mods = "NONE",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.search_forward == false then
					window:perform_action(wezterm.action.CopyMode("PriorMatch"), pane)
				else
					window:perform_action(wezterm.action.CopyMode("NextMatch"), pane)
				end
			end),
		},
		{
			key = "N",
			mods = "SHIFT",
			action = wezterm.action_callback(function(window, pane)
				if wezterm.GLOBAL.search_forward == false then
					window:perform_action(wezterm.action.CopyMode("NextMatch"), pane)
				else
					window:perform_action(wezterm.action.CopyMode("PriorMatch"), pane)
				end
			end),
		},

		{ key = ",", mods = "NONE", action = wezterm.action.CopyMode("JumpReverse") },
		{ key = ";", mods = "NONE", action = wezterm.action.CopyMode("JumpAgain") },

		{
			key = "f",
			action = wezterm.action.CopyMode({ JumpForward = { prev_char = false } }),
		},
		{
			key = "F",
			mods = "SHIFT",
			action = wezterm.action.CopyMode({ JumpBackward = { prev_char = false } }),
		},

		{
			key = "t",
			action = wezterm.action.CopyMode({ JumpForward = { prev_char = true } }),
		},
		{
			key = "T",
			mods = "SHIFT",
			action = wezterm.action.CopyMode({ JumpBackward = { prev_char = true } }),
		},
}

if has_token_motions then
	-- W/B/E: token motions (requires custom wezterm build)
	key_table[#key_table + 1] = { key = "W", mods = "SHIFT", action = wezterm.action.CopyMode("MoveForwardToken") }
	key_table[#key_table + 1] = { key = "E", mods = "SHIFT", action = wezterm.action.CopyMode("MoveForwardTokenEnd") }
	key_table[#key_table + 1] = { key = "B", mods = "SHIFT", action = wezterm.action.CopyMode("MoveBackwardToken") }
end

return {
	get_hint_status_text = get_hint_status_text,
	bracket_back_table = bracket_back_table,
	bracket_forward_table = bracket_forward_table,
	key_table = key_table,
}
