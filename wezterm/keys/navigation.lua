-- ============================================================================
-- NAVIGATION KEYBINDINGS
-- ============================================================================
-- Pane, tab, and workspace navigation

local wezterm = require 'wezterm'
local act = wezterm.action
local pickers = require 'pickers'

local M = {}

function M.get_keys(workspace_switcher)
  local helpers = require 'helpers'

  return {
    -- SMART CLOSE: confirm if editor running, close tab if last pane
    {
      mods = "CMD",
      key = "w",
      action = wezterm.action_callback(function(window, pane)
        local tab = window:active_tab()
        local pane_count = #tab:panes()

        -- If running an editor, require confirmation
        if helpers.is_editor(pane) then
          window:perform_action(act.CloseCurrentPane { confirm = true }, pane)
        elseif pane_count == 1 then
          -- Last pane in tab: close the tab
          window:perform_action(act.CloseCurrentTab { confirm = false }, pane)
        else
          -- Multiple panes: close just this pane
          window:perform_action(act.CloseCurrentPane { confirm = false }, pane)
        end
      end),
    },

    -- SMART SPLIT (uses current layout mode)
    {
      mods = "CMD",
      key = "t",
      action = wezterm.action_callback(function(window, pane)
        local layouts = require 'layouts'
        layouts.smart_new_pane(window, pane)
      end),
    },

    -- QUICK OPEN PICKER
    {
      mods = "CMD",
      key = "n",
      action = wezterm.action_callback(function(window, pane)
        pickers.show_quick_open_picker(window, pane)
      end),
    },
    {
      mods = "CMD",
      key = "p",
      action = wezterm.action_callback(function(window, pane)
        pickers.show_quick_open_picker(window, pane)
      end),
    },
    { mods = "CMD|SHIFT", key = "n", action = act.SpawnWindow },
    { mods = "CMD|SHIFT", key = "f", action = act.ToggleFullScreen },

    -- WORKSPACE AND PANE NAVIGATION
    { mods = "CMD|SHIFT", key = "s", action = act.ShowLauncherArgs { flags = "FUZZY|WORKSPACES" } },
    { mods = "CMD", key = "o", action = workspace_switcher.switch_workspace() },
    { mods = "CMD", key = "e", action = act.PaneSelect { alphabet = "1234567890", mode = "Activate" } },
    { mods = "CMD|SHIFT", key = "e", action = act.PaneSelect { alphabet = "1234567890", mode = "SwapWithActive" } },

    -- COMMAND PALETTE AND LAUNCHER
    { mods = "CMD", key = "l", action = act.ShowLauncher },

    -- PANE NAVIGATION (LEADER KEY)
    { mods = "LEADER", key = "h", action = act.ActivatePaneDirection "Left" },
    { mods = "LEADER", key = "j", action = act.ActivatePaneDirection "Down" },
    { mods = "LEADER", key = "k", action = act.ActivatePaneDirection "Up" },
    { mods = "LEADER", key = "l", action = act.ActivatePaneDirection "Right" },
    { mods = "LEADER", key = "x", action = act.CloseCurrentPane { confirm = true } },

    -- TAB MANAGEMENT (LEADER KEY)
    { mods = "LEADER", key = "c", action = act.SpawnTab "CurrentPaneDomain" },
    { mods = "LEADER", key = "n", action = act.ActivateTabRelative(1) },
    { mods = "LEADER", key = "p", action = act.ActivateTabRelative(-1) },
    -- RENAME TAB
    {
      mods = "LEADER",
      key = ",",
      action = act.PromptInputLine {
        description = "Rename tab:",
        action = wezterm.action_callback(function(window, pane, line)
          if line and line ~= "" then
            window:active_tab():set_title(line)
          end
        end),
      },
    },
    { mods = "LEADER", key = "1", action = act.ActivateTab(0) },
    { mods = "LEADER", key = "2", action = act.ActivateTab(1) },
    { mods = "LEADER", key = "3", action = act.ActivateTab(2) },
    { mods = "LEADER", key = "4", action = act.ActivateTab(3) },
    { mods = "LEADER", key = "5", action = act.ActivateTab(4) },
    { mods = "LEADER", key = "[", action = act.ActivateCopyMode },

    -- ZELLIJ-STYLE PANE NAVIGATION
    { mods = "ALT", key = "h", action = act.ActivatePaneDirection "Left" },
    { mods = "ALT", key = "j", action = act.ActivatePaneDirection "Down" },
    { mods = "ALT", key = "k", action = act.ActivatePaneDirection "Up" },
    { mods = "ALT", key = "l", action = act.ActivatePaneDirection "Right" },

    -- PANE RESIZING
    { mods = "ALT|SHIFT", key = "h", action = act.AdjustPaneSize { "Left", 5 } },
    { mods = "ALT|SHIFT", key = "j", action = act.AdjustPaneSize { "Down", 5 } },
    { mods = "ALT|SHIFT", key = "k", action = act.AdjustPaneSize { "Up", 5 } },
    { mods = "ALT|SHIFT", key = "l", action = act.AdjustPaneSize { "Right", 5 } },

    -- DIRECT PANE SWITCHING
    { mods = "CMD", key = "1", action = act.ActivatePaneByIndex(0) },
    { mods = "CMD", key = "2", action = act.ActivatePaneByIndex(1) },
    { mods = "CMD", key = "3", action = act.ActivatePaneByIndex(2) },
    { mods = "CMD", key = "4", action = act.ActivatePaneByIndex(3) },
    { mods = "CMD", key = "5", action = act.ActivatePaneByIndex(4) },
    { mods = "CMD", key = "6", action = act.ActivatePaneByIndex(5) },
    { mods = "CMD", key = "7", action = act.ActivatePaneByIndex(6) },
    { mods = "CMD", key = "8", action = act.ActivatePaneByIndex(7) },
    { mods = "CMD", key = "9", action = act.ActivatePaneByIndex(8) },

    -- SEARCH
    { mods = "CMD", key = "f", action = act.Search { CaseInSensitiveString = '' } },

    -- PASSTHROUGH READLINE KEYS (disable WezTerm defaults)
    -- Ctrl+K: kill-line in shell (was: ClearScrollback)
    { mods = "CTRL", key = "k", action = act.DisableDefaultAssignment },
    -- Ctrl+X: readline prefix (was: ActivateCopyMode)
    { mods = "CTRL", key = "x", action = act.DisableDefaultAssignment },
  }
end

return M
