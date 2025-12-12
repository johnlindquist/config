-- ============================================================================
-- APPEARANCE MODULE
-- ============================================================================
-- Visual configuration: colors, fonts, window settings

local wezterm = require 'wezterm'
local theme = require 'theme'

local M = {}

function M.apply(config)
  -- COLOR SCHEME
  config.color_scheme = 'Hardcore'

  -- FONT CONFIGURATION
  config.font = wezterm.font 'JetBrains Mono'
  config.font_size = 13.0

  -- WINDOW DECORATIONS
  config.window_decorations = "RESIZE"

  -- WINDOW PADDING
  config.window_padding = {
    left = 10,
    right = 10,
    top = 10,
    bottom = 10,
  }

  -- TAB BAR
  config.hide_tab_bar_if_only_one_tab = false
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = true
  config.tab_max_width = 32

  -- INACTIVE PANE DIMMING
  config.inactive_pane_hsb = {
    brightness = 0.3,
  }

  -- FOCUS FOLLOWS MOUSE (useful for drag-and-drop)
  config.pane_focus_follows_mouse = true

  -- PANE SPLIT LINE AND TAB BAR STYLING
  config.colors = {
    split = theme.colors.pink,
    tab_bar = {
      background = theme.colors.bg,
      active_tab = {
        bg_color = theme.colors.bg_selection,
        fg_color = theme.colors.fg_bright,
        intensity = 'Bold',
      },
      inactive_tab = {
        bg_color = theme.colors.bg,
        fg_color = theme.colors.fg_dim,
      },
      inactive_tab_hover = {
        bg_color = theme.colors.bg_light,
        fg_color = theme.colors.fg,
        italic = false,
      },
      new_tab = {
        bg_color = theme.colors.bg,
        fg_color = theme.colors.fg_dim,
      },
      new_tab_hover = {
        bg_color = theme.colors.bg_selection,
        fg_color = theme.colors.green,
      },
    },
  }

  -- CURSOR CONFIGURATION
  config.default_cursor_style = 'SteadyBar'

  -- VISUAL BELL
  config.audible_bell = "Disabled"
  config.window_close_confirmation = "AlwaysPrompt"
  config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
    target = 'CursorColor',
  }

  -- HYPERLINK RULES
  config.hyperlink_rules = {
    { regex = '\\b\\w+://[\\w.-]+\\.[a-z]{2,15}\\S*\\b', format = '$0' },
    { regex = '\\b[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+\\b', format = 'mailto:$0' },
    { regex = '\\b(/[\\w.-]+)+/?\\b', format = 'file://$0' },
  }
end

return M
