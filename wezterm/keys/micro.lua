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
          -- Toggle pane zoom (expand focused pane / restore grid)
          window:perform_action(act.TogglePaneZoomState, pane)
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
          return
        end

        -- Equalize all panes: unzoom first, then balance sizes
        local ok, err = pcall(function()
          -- Unzoom to show all panes
          window:perform_action(act.SetPaneZoomState(false), pane)

          local tab = window:active_tab()
          local panes = tab:panes()
          local n = #panes

          if n <= 1 then
            window:toast_notification('Panes', 'Only one pane', nil, 1000)
            return
          end

          -- Simple approach: repeatedly adjust undersized panes to grow
          -- As small panes grow, they take space from oversized panes
          local tab_size = tab:get_size()
          local target_width = math.floor(tab_size.cols / n)
          local target_height = math.floor(tab_size.rows / n)

          for pass = 1, 10 do
            for _, p in ipairs(tab:panes()) do
              local dims = p:get_dimensions()

              -- If pane is smaller than target, try to expand it
              if dims.cols < target_width - 2 then
                local grow = math.max(1, math.floor((target_width - dims.cols) / 2))
                window:perform_action(act.AdjustPaneSize{"Right", grow}, p)
              end
              if dims.viewport_rows < target_height - 2 then
                local grow = math.max(1, math.floor((target_height - dims.viewport_rows) / 2))
                window:perform_action(act.AdjustPaneSize{"Down", grow}, p)
              end
            end
          end

          window:toast_notification('Panes', 'Equalized ' .. n .. ' panes', nil, 1500)
        end)

        if not ok then
          window:toast_notification('Error', tostring(err), nil, 3000)
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
