-- ============================================================================
-- KEYBINDINGS MODULE
-- ============================================================================
-- Aggregates all keybindings from sub-modules

local wezterm = require 'wezterm'
local act = wezterm.action

local micro_keys = require 'keys.micro'
local navigation_keys = require 'keys.navigation'
local layout_keys = require 'keys.layouts'
local power_keys = require 'keys.power'

local M = {}

function M.apply(config, workspace_switcher, resurrect)
  -- Leader key configuration
  config.leader = { key = 'l', mods = 'ALT', timeout_milliseconds = 2000 }

  -- Aggregate all keys
  config.keys = {}

  -- Add micro editor keys
  for _, key in ipairs(micro_keys.get_keys()) do
    table.insert(config.keys, key)
  end

  -- Add navigation keys
  for _, key in ipairs(navigation_keys.get_keys(workspace_switcher)) do
    table.insert(config.keys, key)
  end

  -- Add layout keys
  for _, key in ipairs(layout_keys.get_keys()) do
    table.insert(config.keys, key)
  end

  -- Add power user keys
  for _, key in ipairs(power_keys.get_keys(resurrect, config.color_scheme)) do
    table.insert(config.keys, key)
  end

  -- Key tables for modal keybindings
  config.key_tables = {
    resize_pane = {
      { key = 'h', action = act.AdjustPaneSize { 'Left', 1 } },
      { key = 'j', action = act.AdjustPaneSize { 'Down', 1 } },
      { key = 'k', action = act.AdjustPaneSize { 'Up', 1 } },
      { key = 'l', action = act.AdjustPaneSize { 'Right', 1 } },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'Enter', action = 'PopKeyTable' },
    },
  }

  -- Add resize mode activation
  table.insert(config.keys, {
    mods = "LEADER",
    key = "r",
    action = act.ActivateKeyTable { name = 'resize_pane', one_shot = false },
  })
end

return M
