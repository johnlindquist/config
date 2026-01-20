-- ============================================================================
-- POWER USER KEYBINDINGS
-- ============================================================================
-- Session management, themes, zen mode, etc.

local wezterm = require 'wezterm'
local act = wezterm.action
local helpers = require 'helpers'
local theme = require 'theme'
local pickers = require 'pickers'

local M = {}

function M.get_keys(resurrect, default_color_scheme)
  return {
    -- KEYBOARD SHORTCUTS HELP
    {
      mods = "CMD",
      key = "/",
      action = wezterm.action_callback(function(window, pane)
        pickers.show_shortcuts_picker(window, pane)
      end),
    },

    -- SESSION PERSISTENCE
    {
      mods = "LEADER",
      key = "s",
      action = wezterm.action_callback(function(win, pane)
        resurrect.save_state(resurrect.workspace_state.get_workspace_state())
      end),
    },

    -- QUICK SELECT
    { mods = "LEADER", key = "Space", action = act.QuickSelect },

    -- THEME SWITCHER
    {
      mods = "CMD|SHIFT",
      key = "t",
      action = wezterm.action_callback(function(window, pane)
        local choices = {}
        for _, t in ipairs(theme.high_contrast_themes) do
          table.insert(choices, { id = t.id, label = t.name .. ' - ' .. t.desc })
        end
        window:perform_action(
          act.InputSelector({
            title = wezterm.format({
              { Foreground = { Color = theme.colors.cyan } },
              { Attribute = { Intensity = "Bold" } },
              { Text = "  Select Theme" },
            }),
            description = wezterm.format({
              { Foreground = { Color = theme.colors.fg_dim } },
              { Text = "High contrast themes for better readability" },
            }),
            fuzzy_description = wezterm.format({
              { Foreground = { Color = theme.colors.pink } },
              { Attribute = { Intensity = "Bold" } },
              { Text = " Search: " },
            }),
            choices = choices,
            fuzzy = true,
            action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
              if id then
                wezterm.GLOBAL.user_selected_theme = id
                local overrides = inner_window:get_config_overrides() or {}
                overrides.color_scheme = id
                inner_window:set_config_overrides(overrides)
              end
            end),
          }),
          pane
        )
      end),
    },

    -- QUICK THEME CYCLE
    {
      mods = "LEADER",
      key = "t",
      action = wezterm.action_callback(function(window, pane)
        local overrides = window:get_config_overrides() or {}
        local current = overrides.color_scheme or default_color_scheme
        local current_idx = 1
        for i, t in ipairs(theme.high_contrast_themes) do
          if t.id == current then
            current_idx = i
            break
          end
        end
        local next_idx = (current_idx % #theme.high_contrast_themes) + 1
        local next_theme = theme.high_contrast_themes[next_idx]
        wezterm.GLOBAL.user_selected_theme = next_theme.id
        overrides.color_scheme = next_theme.id
        window:set_config_overrides(overrides)
      end),
    },

    -- RESTORE AUTO-THEME (clear user selection, return to CWD-based theming)
    {
      mods = "LEADER|SHIFT",
      key = "t",
      action = wezterm.action_callback(function(window, pane)
        wezterm.GLOBAL.user_selected_theme = nil
        local overrides = window:get_config_overrides() or {}
        overrides.color_scheme = nil
        window:set_config_overrides(overrides)
      end),
    },

    -- ZEN MODE (Leader+z)
    {
      mods = "LEADER",
      key = "z",
      action = wezterm.action_callback(function(window, pane)
        local overrides = window:get_config_overrides() or {}
        if overrides.enable_tab_bar == false then
          overrides.enable_tab_bar = true
          overrides.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
        else
          overrides.enable_tab_bar = false
          overrides.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
        end
        window:set_config_overrides(overrides)
      end),
    },

    -- ZEN MODE / PRESENTER MODE (Cmd+Shift+P)
    {
      mods = "CMD|SHIFT",
      key = "p",
      action = wezterm.action_callback(function(window, pane)
        local overrides = window:get_config_overrides() or {}
        if overrides.enable_tab_bar == false then
          overrides.enable_tab_bar = true
          overrides.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
        else
          overrides.enable_tab_bar = false
          overrides.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
        end
        window:set_config_overrides(overrides)
      end),
    },

    -- RECORDING MODE (hide tab bar + status bar for demos/lessons)
    {
      mods = "CMD|SHIFT",
      key = "r",
      action = wezterm.action_callback(function(window, pane)
        wezterm.GLOBAL.recording_mode = not wezterm.GLOBAL.recording_mode
        local overrides = window:get_config_overrides() or {}
        if wezterm.GLOBAL.recording_mode then
          overrides.enable_tab_bar = false
        else
          overrides.enable_tab_bar = true
        end
        window:set_config_overrides(overrides)
      end),
    },

    -- SMART SCROLLBACK CLEAR (CMD+SHIFT+K to avoid conflict with Command Palette)
    {
      mods = "CMD|SHIFT",
      key = "k",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_vim(pane) then
          window:perform_action(act.SendKey({ key = 'k', mods = 'CMD' }), pane)
        else
          window:perform_action(act.ClearScrollback 'ScrollbackOnly', pane)
          window:perform_action(act.SendKey({ key = 'L', mods = 'CTRL' }), pane)
        end
      end),
    },

    -- OPEN ZED AT CURRENT DIRECTORY
    {
      mods = "CMD",
      key = "z",
      action = wezterm.action_callback(function(window, pane)
        local cwd = pane:get_current_working_dir()
        local path = cwd and cwd.file_path or os.getenv("HOME")
        wezterm.background_child_process({ "/usr/local/bin/zed", path })
      end),
    },

    -- QUICK COMMAND PANES (uses BSP layout like Cmd+T)
    -- Cmd+X: Open new pane and run 'x' alias
    {
      mods = "CMD",
      key = "x",
      action = wezterm.action_callback(function(window, pane)
        local layouts = require 'layouts'
        layouts.smart_new_pane(window, pane, { args = { "/bin/zsh", "-ic", "x; exec zsh" } })
      end),
    },
    -- Cmd+Y: Open new pane and run 'ocy' alias
    {
      mods = "CMD",
      key = "y",
      action = wezterm.action_callback(function(window, pane)
        local layouts = require 'layouts'
        layouts.smart_new_pane(window, pane, { args = { "/bin/zsh", "-ic", "ocy; exec zsh" } })
      end),
    },
  }
end

return M
