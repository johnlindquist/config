-- ============================================================================
-- MICRO EDITOR KEYBINDINGS
-- ============================================================================
-- Mac-style Cmd key mappings for micro editor

local wezterm = require 'wezterm'
local act = wezterm.action
local helpers = require 'helpers'

local M = {}

function M.get_keys()
  return {
    {
      mods = "CMD",
      key = "s",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 's', mods = 'CTRL' }), pane)
        else
          -- Cycle to next pane
          local tab = window:active_tab()
          local panes = tab:panes()
          if #panes > 1 then
            local current_idx = 0
            for i, p in ipairs(panes) do
              if p:pane_id() == pane:pane_id() then
                current_idx = i
                break
              end
            end
            local next_idx = (current_idx % #panes)  -- 0-based for ActivatePaneByIndex
            window:perform_action(act.ActivatePaneByIndex(next_idx), pane)
          end
        end
      end),
    },
    {
      mods = "CMD",
      key = "q",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'q', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.QuitApplication, pane)
        end
      end),
    },
    {
      mods = "CMD",
      key = "z",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'z', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.SendKey({ key = 'z', mods = 'CMD' }), pane)
        end
      end),
    },
    {
      mods = "CMD|SHIFT",
      key = "z",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'y', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.SendKey({ key = 'z', mods = 'CMD|SHIFT' }), pane)
        end
      end),
    },
    {
      mods = "CMD",
      key = "c",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'c', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.CopyTo('Clipboard'), pane)
        end
      end),
    },
    {
      mods = "CMD",
      key = "v",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'v', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.PasteFrom('Clipboard'), pane)
        end
      end),
    },
    {
      mods = "CMD",
      key = "x",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'x', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.SendKey({ key = 'x', mods = 'CMD' }), pane)
        end
      end),
    },
    {
      mods = "CMD",
      key = "a",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'a', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.SendKey({ key = 'a', mods = 'CMD' }), pane)
        end
      end),
    },
    {
      mods = "CMD",
      key = "g",
      action = wezterm.action_callback(function(window, pane)
        if helpers.is_micro(pane) then
          window:perform_action(act.SendKey({ key = 'g', mods = 'CTRL' }), pane)
        else
          window:perform_action(act.SendKey({ key = 'g', mods = 'CMD' }), pane)
        end
      end),
    },
  }
end

return M
