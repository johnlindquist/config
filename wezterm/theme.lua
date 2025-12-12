-- ============================================================================
-- THEME MODULE
-- ============================================================================
-- Color scheme definitions and theme-related utilities

local M = {}

-- Hardcore theme colors for UI elements
M.colors = {
  bg = '#121212',           -- Background (very dark)
  bg_light = '#1b1d1e',     -- Slightly lighter background
  bg_selection = '#453b39', -- Selection/highlight background
  fg = '#a0a0a0',           -- Main foreground (gray)
  fg_bright = '#f8f8f2',    -- Bright foreground (white)
  fg_dim = '#505354',       -- Dimmed foreground
  pink = '#f92672',         -- Accent: pink/magenta
  green = '#a6e22e',        -- Accent: green
  orange = '#fd971f',       -- Accent: orange
  yellow = '#e6db74',       -- Accent: yellow
  cyan = '#66d9ef',         -- Accent: cyan
  purple = '#9e6ffe',       -- Accent: purple
}

-- High contrast theme options
M.high_contrast_themes = {
  { id = 'Solarized Dark Higher Contrast', name = 'Solarized High Contrast', desc = 'Enhanced Solarized readability' },
  { id = 'Hardcore', name = 'Hardcore', desc = 'Maximum contrast, bold colors' },
  { id = 'Dracula', name = 'Dracula', desc = 'Dark purple with vivid accents' },
  { id = 'Catppuccin Mocha', name = 'Catppuccin Mocha', desc = 'Warm pastels, good contrast' },
  { id = 'GruvboxDark', name = 'Gruvbox Dark', desc = 'Warm retro classic' },
  { id = 'Tokyo Night', name = 'Tokyo Night', desc = 'Cool blue/purple palette' },
  { id = 'Selenized Dark (Gogh)', name = 'Selenized Dark', desc = 'Scientifically designed readability' },
  { id = 'Snazzy', name = 'Snazzy', desc = 'Vibrant on dark' },
}

-- Dynamic theme based on macOS appearance
function M.scheme_for_appearance(appearance)
  if appearance:find("Dark") then
    return "Catppuccin Mocha"
  else
    return "Catppuccin Latte"
  end
end

return M
