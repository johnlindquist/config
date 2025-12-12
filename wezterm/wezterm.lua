-- ============================================================================
-- WEZTERM CONFIGURATION
-- ============================================================================
-- WezTerm is a GPU-accelerated terminal emulator written in Rust.
-- This config transforms WezTerm into a powerful terminal multiplexer,
-- combining features from tmux, Zellij, and iTerm2 into one cohesive setup.
--
-- MODULAR STRUCTURE:
--   helpers.lua    - Utility functions (is_vim, is_micro, cwd helpers)
--   theme.lua      - Color schemes and theme definitions
--   layouts.lua    - Zellij-style layouts and smart pane management
--   appearance.lua - Visual config (fonts, colors, window settings)
--   pickers.lua    - Fuzzy pickers for tabs, directories, themes
--   keys/          - Keybindings split by category
--   events.lua     - Event handlers (tab titles, status bar)
-- ============================================================================

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Load modules
local appearance = require 'appearance'
local events = require 'events'
local keys = require 'keys'

-- ============================================================================
-- PLUGINS
-- ============================================================================
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

-- ============================================================================
-- APPLY CONFIGURATION
-- ============================================================================

-- Apply appearance settings
appearance.apply(config)

-- Apply keybindings (needs plugins for some bindings)
keys.apply(config, workspace_switcher, resurrect)

-- Setup event handlers
events.setup()

-- Apply plugin configurations
workspace_switcher.apply_to_config(config)

-- ============================================================================
-- RETURN CONFIGURATION
-- ============================================================================
return config
