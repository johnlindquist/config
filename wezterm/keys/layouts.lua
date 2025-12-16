-- ============================================================================
-- LAYOUT KEYBINDINGS
-- ============================================================================
-- Pane splitting and layout management

local wezterm = require 'wezterm'
local act = wezterm.action
local layouts = require 'layouts'

local M = {}

function M.get_keys()
  return {
    -- PANE SPLITTING
    { mods = "LEADER", key = "-", action = act.SplitVertical { domain = "CurrentPaneDomain" } },
    { mods = "LEADER", key = "|", action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },
    {
      mods = "CMD",
      key = "d",
      action = wezterm.action_callback(function(window, pane)
        layouts.smart_new_pane(window, pane)
      end),
    },
    { mods = "CMD|SHIFT", key = "d", action = act.SplitVertical { domain = "CurrentPaneDomain" } },

    -- ZELLIJ-STYLE AUTO-LAYOUT
    {
      mods = "ALT",
      key = "n",
      action = wezterm.action_callback(function(window, pane)
        layouts.smart_new_pane(window, pane)
      end),
    },
    {
      mods = "ALT",
      key = "]",
      action = wezterm.action_callback(function(window, pane)
        local tab = window:active_tab()
        local current = layouts.get_layout_mode(tab)
        local new_mode = layouts.cycle_layout_mode(current, 1)
        layouts.set_layout_mode(tab, new_mode)
        local mode_name = new_mode
        for _, m in ipairs(layouts.LAYOUT_MODES) do
          if m.id == new_mode then mode_name = m.name .. ' - ' .. m.desc break end
        end
      end),
    },
    {
      mods = "ALT",
      key = "[",
      action = wezterm.action_callback(function(window, pane)
        local tab = window:active_tab()
        local current = layouts.get_layout_mode(tab)
        local new_mode = layouts.cycle_layout_mode(current, -1)
        layouts.set_layout_mode(tab, new_mode)
        local mode_name = new_mode
        for _, m in ipairs(layouts.LAYOUT_MODES) do
          if m.id == new_mode then mode_name = m.name .. ' - ' .. m.desc break end
        end
      end),
    },
    {
      mods = "ALT",
      key = "Space",
      action = wezterm.action.InputSelector({
        title = "Select Layout Mode (Zellij-style)",
        choices = (function()
          local choices = {}
          for _, mode in ipairs(layouts.LAYOUT_MODES) do
            table.insert(choices, { id = mode.id, label = mode.name .. ' - ' .. mode.desc })
          end
          return choices
        end)(),
        action = wezterm.action_callback(function(window, pane, id, label)
          if id then
            local tab = window:active_tab()
            layouts.set_layout_mode(tab, id)
          end
        end),
      }),
    },
    {
      mods = "ALT",
      key = "r",
      action = wezterm.action_callback(function(window, pane)
        window:perform_action(act.RotatePanes "Clockwise", pane)
      end),
    },
    { mods = "ALT", key = "=", action = act.SetPaneZoomState(false) },
    {
      mods = "ALT",
      key = "Enter",
      action = act.Multiple({
        act.SetPaneZoomState(false),
        act.AdjustPaneSize { "Left", 15 },
        act.AdjustPaneSize { "Right", 15 },
        act.AdjustPaneSize { "Up", 8 },
        act.AdjustPaneSize { "Down", 8 },
      }),
    },
    {
      mods = "ALT",
      key = "f",
      action = wezterm.action_callback(function(window, pane)
        window:perform_action(act.TogglePaneZoomState, pane)
      end),
    },
    {
      mods = "ALT",
      key = "x",
      action = wezterm.action_callback(function(window, pane)
        window:perform_action(act.CloseCurrentPane { confirm = false }, pane)
      end),
    },
    { mods = "LEADER", key = "z", action = act.TogglePaneZoomState },

    -- STATIC LAYOUT TEMPLATES
    {
      mods = "CMD|SHIFT",
      key = "l",
      action = wezterm.action.InputSelector({
        title = "Select Layout",
        choices = (function()
          local choices = {}
          for _, layout in ipairs(layouts.layout_list) do
            table.insert(choices, { id = layout.id, label = layout.name .. ' - ' .. layout.desc })
          end
          return choices
        end)(),
        action = wezterm.action_callback(function(window, pane, id, label)
          if id then
            layouts.apply_layout(window, id)
          end
        end),
      }),
    },
    { mods = "LEADER|SHIFT", key = "d", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'dev') end) },
    { mods = "LEADER|SHIFT", key = "e", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'editor') end) },
    { mods = "LEADER|SHIFT", key = "3", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'three_col') end) },
    { mods = "LEADER|SHIFT", key = "4", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'quad') end) },
    { mods = "LEADER|SHIFT", key = "s", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'stacked') end) },
    { mods = "LEADER|SHIFT", key = "v", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'side_by_side') end) },
    { mods = "LEADER|SHIFT", key = "f", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'focus') end) },
    { mods = "LEADER|SHIFT", key = "m", action = wezterm.action_callback(function(w, p) layouts.apply_layout(w, 'monitor') end) },
    { mods = "LEADER", key = "Enter", action = act.PaneSelect { mode = "SwapWithActive" } },
  }
end

return M
