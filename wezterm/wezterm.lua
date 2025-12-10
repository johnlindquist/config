-- ============================================================================
-- WEZTERM CONFIGURATION
-- ============================================================================
-- WezTerm is a GPU-accelerated terminal emulator written in Rust.
-- This config transforms WezTerm into a powerful terminal multiplexer,
-- combining features from tmux, Zellij, and iTerm2 into one cohesive setup.
--
-- Key design goals:
-- 1. MULTIPLEXER BUILT-IN: No need for tmux/Zellij - use native panes/tabs
-- 2. SMART LAYOUTS: Automatic pane arrangement like Zellij's swap layouts
-- 3. WORKSPACE MANAGEMENT: Project-based workspaces with zoxide integration
-- 4. FUZZY FINDING: Quick navigation with fuzzy pickers for everything
-- 5. MINIMAL UI: Clean interface that stays out of the way
-- ============================================================================
--
-- ============================================================================
-- WEZTERM'S SUPERPOWER: LUA SCRIPTING
-- ============================================================================
-- Unlike most terminal emulators that only offer static configuration,
-- WezTerm embeds a full Lua interpreter. This means you can:
--
--   1. DEFINE CUSTOM FUNCTIONS - Write reusable logic for complex behaviors
--   2. CREATE EVENT HANDLERS - React to terminal events (focus, resize, etc.)
--   3. USE wezterm.action_callback() - Build keybindings that execute ANY Lua code
--   4. ACCESS RUNTIME STATE - Query panes, tabs, windows, processes dynamically
--   5. INTEGRATE EXTERNAL TOOLS - Shell out to zoxide, git, or any CLI tool
--
-- This transforms configuration from "set some options" to "program your terminal."
--
-- ============================================================================
-- WHERE WE USE THESE SUPERPOWERS IN THIS FILE:
-- ============================================================================
--
-- CUSTOM FUNCTIONS (reusable logic):
--   • is_vim()                                 - Detect Neovim for smart keybindings
--   • get_layout_mode() / set_layout_mode()   - Track layout state per tab
--   • cycle_layout_mode()                     - Cycle through layout options
--   • get_smart_split_direction()             - Calculate optimal split direction
--   • smart_new_pane()                        - Zellij-style intelligent pane creation
--   • layouts.dev(), layouts.quad(), etc.     - Programmatic layout templates
--   • apply_layout()                          - Apply layouts by name
--   • short_cwd()                             - Format paths for display
--   • scheme_for_cwd()                        - Dynamic theming based on directory
--
-- EVENT HANDLERS (react to terminal events):
--   • wezterm.on('format-tab-title', ...)     - Custom tab title formatting
--   • wezterm.on('format-window-title', ...)  - Custom window title
--   • wezterm.on('update-status', ...)        - Dynamic status bar with live data
--
-- ACTION CALLBACKS (keybindings that run Lua):
--   • Cmd+T      → Spawns tab + shows zoxide picker (two actions chained)
--   • Cmd+P      → Builds dynamic tab list with process info for fuzzy search
--   • Cmd+K      → Vim-aware scrollback clear (passes through in Neovim)
--   • Alt+N      → Calls smart_new_pane() for layout-aware splitting
--   • Alt+]/[    → Cycles layout modes with toast notifications
--   • Alt+Space  → Builds layout mode picker dynamically
--   • Leader+Z   → Zen mode toggle (hide UI for focus)
--
-- KEY TABLES (modal keybindings):
--   • resize_pane → Enter resize mode with Leader+R, use hjkl freely
--
-- PLUGINS:
--   • workspace_switcher  - zoxide-powered workspace switching
--   • resurrect           - Session persistence (save/restore workspaces)
--
-- This level of customization is simply impossible in terminals like iTerm2,
-- Alacritty, or Kitty. WezTerm lets you BUILD your ideal terminal workflow.
-- ============================================================================

-- Import WezTerm's Lua API modules
local wezterm = require 'wezterm'    -- Core API for configuration and utilities
local config = wezterm.config_builder()  -- Type-safe config builder (validates options)
local act = wezterm.action           -- Shorthand for action definitions (keybindings)
local mux = wezterm.mux              -- Multiplexer API for programmatic control

-- ============================================================================
-- HELPER FUNCTIONS (POWER USER UTILITIES)
-- ============================================================================

-- Detect if the current pane is running Neovim/Vim
-- WHY: Many keybindings should behave differently in Vim vs shell.
-- For example, Cmd+K should clear scrollback in shell but pass through to Vim.
-- Used by: Smart navigation, smart scrollback clear
local function is_vim(pane)
  local process_info = pane:get_foreground_process_info()
  local process_name = process_info and process_info.executable or ""
  return process_name:find("n?vim") ~= nil
end

-- ============================================================================
-- ZELLIJ-STYLE AUTO-LAYOUT SYSTEM
-- ============================================================================
-- WHY: Zellij popularized "swap layouts" - the ability to cycle through
-- different pane arrangements on the fly. This replicates that in WezTerm.
--
-- HOW IT WORKS:
-- 1. Each tab has a "layout mode" stored in wezterm.GLOBAL (persists across reloads)
-- 2. When creating new panes with Alt+n, the split direction is chosen based on mode
-- 3. Alt+[ and Alt+] cycle through layout modes
-- 4. A status bar indicator shows the current mode
--
-- MODES EXPLAINED:
-- - tiled: Grid layout that alternates split direction based on pane aspect ratio
--   └── Like a tiling window manager - splits the larger dimension
-- - vertical: All panes stacked top-to-bottom (good for wide monitors)
-- - horizontal: All panes side-by-side (good for tall monitors or reading logs)
-- - main-vertical: Main editor pane on left (60%), terminal stack on right (40%)
--   └── Classic development layout: code left, terminals right
-- - main-horizontal: Main pane on top (60%), stack on bottom (40%)
--   └── Useful for video editing or preview workflows

local DEFAULT_LAYOUT_MODE = 'tiled'  -- Start in tiled mode for general use

-- ============================================================================
-- LAYOUT MODE STATE MANAGEMENT
-- ============================================================================
-- WHY wezterm.GLOBAL: WezTerm provides a GLOBAL table that persists across
-- config reloads. This is perfect for storing state like the current layout
-- mode per tab. Without this, state would be lost every time the config reloads.
--
-- WHY tostring(tab_id): Tab IDs are numbers, but Lua table keys work best as
-- strings when we want predictable serialization behavior.

-- Get current layout mode for a tab (stored in global)
local function get_layout_mode(tab)
  -- Ensure the layout_modes table exists (defensive initialization)
  wezterm.GLOBAL.layout_modes = wezterm.GLOBAL.layout_modes or {}
  -- Return stored mode or default if none set
  return wezterm.GLOBAL.layout_modes[tostring(tab:tab_id())] or DEFAULT_LAYOUT_MODE
end

-- Set layout mode for a tab
local function set_layout_mode(tab, mode)
  wezterm.GLOBAL.layout_modes = wezterm.GLOBAL.layout_modes or {}
  wezterm.GLOBAL.layout_modes[tostring(tab:tab_id())] = mode
end

-- ============================================================================
-- LAYOUT MODE DEFINITIONS
-- ============================================================================
-- WHY this structure: Having layout modes as a list of tables allows us to:
-- 1. Display them in the UI with human-readable names and descriptions
-- 2. Cycle through them in order with Alt+[ and Alt+]
-- 3. Build fuzzy picker choices dynamically
-- The 'id' is used internally, 'name' for display, 'desc' for help text.

local LAYOUT_MODES = {
  { id = 'tiled',           name = 'Tiled',           desc = 'Grid layout (Zellij default)' },
  { id = 'vertical',        name = 'Vertical',        desc = 'All panes stacked vertically' },
  { id = 'horizontal',      name = 'Horizontal',      desc = 'All panes side by side' },
  { id = 'main-vertical',   name = 'Main+Vertical',   desc = 'Main left, stack right' },
  { id = 'main-horizontal', name = 'Main+Horizontal', desc = 'Main top, stack bottom' },
}

-- ============================================================================
-- LAYOUT MODE CYCLING
-- ============================================================================
-- WHY cycling: Rather than memorizing which key goes to which layout, users
-- can just press Alt+] repeatedly until they find the layout they want.
-- This mirrors how Zellij's Tab key cycles through layouts.

-- Get next/previous layout mode (wraps around at boundaries)
local function cycle_layout_mode(current, direction)
  -- Find the index of the current mode in the list
  local current_idx = 1
  for i, mode in ipairs(LAYOUT_MODES) do
    if mode.id == current then
      current_idx = i
      break
    end
  end
  -- Calculate new index with wrapping
  local new_idx = current_idx + direction
  if new_idx < 1 then new_idx = #LAYOUT_MODES end        -- Wrap to end
  if new_idx > #LAYOUT_MODES then new_idx = 1 end        -- Wrap to start
  return LAYOUT_MODES[new_idx].id
end

-- ============================================================================
-- HELPER FUNCTIONS FOR SMART LAYOUTS
-- ============================================================================

-- Debug flag: set to true to enable logging
local DEBUG_LAYOUTS = false

-- Percent helper for pane:split size (pane:split wants a NUMBER, not {Percent=N})
local function pct(n) return n / 100.0 end

-- Safe cwd extraction (handles both string and Url object formats)
-- WHY: pane:get_current_working_dir() returned a string historically,
-- but now returns a Url object with .file_path property
local function cwd_path(cwd)
  if not cwd then return nil end
  if type(cwd) == "string" then return cwd end
  return cwd.file_path
end

-- Calculate split size based on pane count and layout mode
local function get_split_size(mode, pane_count)
  if mode == 'main-vertical' or mode == 'main-horizontal' then
    return (pane_count == 1) and pct(40) or pct(50)
  end
  return pct(50)
end

-- Pick the "stack" target pane based on pane geometry, not list order
-- WHY: panes[#panes] isn't reliable - pane order doesn't match visual position.
-- Use tab:panes_with_info() to get coordinates and pick by position.
local function pick_stack_pane(tab, mode)
  local info = tab:panes_with_info()
  if #info == 0 then
    return tab:active_pane()
  end

  local best = info[1]
  if mode == 'main-vertical' then
    -- Rightmost pane; tie-breaker = lowest (largest top value)
    for _, p in ipairs(info) do
      if (p.left > best.left) or (p.left == best.left and p.top > best.top) then
        best = p
      end
    end
  else
    -- main-horizontal: Bottommost pane; tie-breaker = rightmost (largest left)
    for _, p in ipairs(info) do
      if (p.top > best.top) or (p.top == best.top and p.left > best.left) then
        best = p
      end
    end
  end

  return best.pane
end

-- ============================================================================
-- SMART SPLIT DIRECTION CALCULATION
-- ============================================================================
-- WHY: The "tiled" mode uses aspect ratio to decide split direction, which
-- creates more balanced layouts. Wide panes split horizontally, tall panes
-- split vertically. This prevents the "all vertical strips" problem you get
-- with naive splitting.
--
-- FIX: Terminal cells aren't square - they're taller than wide (typical aspect
-- ratio ~2.2:1). We multiply height by 2.2 to compare actual visual dimensions
-- rather than raw cell counts. Without this, "tiled" mode creates too many
-- vertical splits.

-- Calculate optimal split direction based on pane dimensions and layout mode
local function get_smart_split_direction(pane, mode, pane_count)
  -- Get pane dimensions in cells (cols/rows, not pixels)
  local dims = pane:get_dimensions()
  local width = dims.cols                    -- Width in character columns
  -- FIX: Multiply height by 2.2 to adjust for cell aspect ratio
  local height = dims.viewport_rows * 2.2    -- Adjusted for cell aspect ratio

  if mode == 'vertical' then
    return 'Bottom'
  elseif mode == 'horizontal' then
    return 'Right'
  elseif mode == 'main-vertical' then
    return pane_count == 1 and 'Right' or 'Bottom'
  elseif mode == 'main-horizontal' then
    return pane_count == 1 and 'Bottom' or 'Right'
  else
    -- 'tiled' mode: Split the larger visual dimension
    return (width > height) and 'Right' or 'Bottom'
  end
end

-- ============================================================================
-- SMART NEW PANE FUNCTION
-- ============================================================================
-- WHY: This is the core of the Zellij-style layout system. Instead of users
-- manually choosing split direction each time, this function makes intelligent
-- choices based on the current layout mode.
--
-- BEHAVIOR: Pressing Alt+n or Cmd+D creates a new pane using the current
-- layout mode's logic. For main layouts, it correctly targets the stack pane
-- by geometry (not list order).

-- Smart new pane: creates a pane using Zellij-style auto-layout
local function smart_new_pane(window, pane)
  local tab = window:active_tab()
  if not tab then return end
  
  local mode = get_layout_mode(tab)
  local pane_count = #tab:panes()

  -- Preserve working directory
  local cwd = cwd_path(pane:get_current_working_dir())

  -- Choose target pane: for main layouts, pick the stack pane by geometry
  local target = pane
  if (mode == 'main-vertical' or mode == 'main-horizontal') and pane_count > 1 then
    target = pick_stack_pane(tab, mode)
  end

  local direction = get_smart_split_direction(target, mode, pane_count)
  local size = get_split_size(mode, pane_count)

  -- Build split arguments
  local split_args = { direction = direction, size = size }
  if cwd then
    split_args.cwd = cwd
  end

  -- Perform the split
  local success, result = pcall(function()
    return target:split(split_args)
  end)
  
  if DEBUG_LAYOUTS then
    local log_file = io.open(os.getenv("HOME") .. "/.config/wezterm/debug.log", "a")
    if log_file then
      log_file:write(string.format("%s smart_new_pane: mode=%s dir=%s size=%s success=%s\n",
        os.date("%H:%M:%S"), mode, direction, size, tostring(success)))
      log_file:close()
    end
  end

  -- Activate the new pane for predictable focus behavior
  if success and result then
    result:activate()
  end
end

-- ============================================================================
-- STATIC LAYOUT TEMPLATES
-- ============================================================================
-- WHY: While the Zellij-style system builds layouts incrementally, sometimes
-- you want to jump directly to a specific layout. These templates create
-- complete layouts in one action, useful for:
-- - Starting a new project with a known setup
-- - Quickly recreating a layout after closing tabs
-- - Demonstrating different layout possibilities
--
-- HOW TO USE: Press Cmd+Shift+L to open the layout picker, or use the
-- Leader+Shift+<key> shortcuts for direct access.
--
-- ASCII DIAGRAMS: Each function includes an ASCII diagram showing the final
-- layout. This helps visualize what you'll get before applying it.

local layouts = {}

-- ============================================================================
-- DEV LAYOUT: The classic development setup
-- ============================================================================
-- WHY 60/40 split: Gives the editor enough width for ~120 columns of code
-- while leaving meaningful space for terminal output.
--
-- WHY stacked terminals: Having multiple terminals (one for commands, one for
-- logs/tests) is more efficient than constantly switching in a single terminal.
--
-- USE CASE: General software development with an editor and terminal workflow.
-- ┌──────────────────┬─────────────┐
-- │                  │   terminal  │  <- git, commands
-- │     editor       ├─────────────┤
-- │                  │   terminal  │  <- tests, logs
-- └──────────────────┴─────────────┘
function layouts.dev(window, cwd)
  -- Create a new tab (we don't modify the existing tab to preserve user's work)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- Create right side (40% of total width) for terminal stack
  local right = main:split({ direction = 'Right', size = pct(40), cwd = cwd })
  -- Split the right pane in half vertically for two terminals
  right:split({ direction = 'Bottom', size = pct(50), cwd = cwd })

  -- Set layout mode so Alt+N/Cmd+D continues the pattern
  set_layout_mode(tab, 'main-vertical')
  tab:set_title('dev')
  return tab
end

-- ============================================================================
-- EDITOR LAYOUT: Maximum editing space with quick terminal access
-- ============================================================================
-- WHY 75/25 split: The editor gets maximum vertical space while the terminal
-- remains accessible for quick commands without switching tabs.
--
-- WHY bottom terminal: Keeps the mental model of "code above, output below"
-- which matches how many IDEs arrange their layouts.
--
-- USE CASE: Writing, documentation, or code review where you need to see as
-- much content as possible but occasionally run commands.
-- ┌────────────────────────────────┐
-- │                                │
-- │           editor               │  <- main focus area
-- │                                │
-- ├────────────────────────────────┤
-- │           terminal             │  <- quick commands
-- └────────────────────────────────┘
function layouts.editor(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- Bottom terminal gets 25% of height - enough for a few lines of output
  main:split({ direction = 'Bottom', size = pct(25), cwd = cwd })

  -- Set layout mode so Alt+N/Cmd+D continues the pattern
  set_layout_mode(tab, 'main-horizontal')
  tab:set_title('editor')
  return tab
end

-- ============================================================================
-- THREE COLUMN LAYOUT: Comparing or monitoring multiple sources
-- ============================================================================
-- WHY equal thirds: Gives each column meaningful width for content comparison.
--
-- MATH NOTE: We split 66% right first, leaving 33% left. Then we split that
-- 66% in half (50%), giving us 33% + 33% = 66% for the remaining two columns.
--
-- USE CASE: Comparing files, monitoring multiple logs, or working with
-- microservices that need simultaneous terminals.
-- ┌──────────┬──────────┬──────────┐
-- │          │          │          │
-- │   left   │  center  │  right   │
-- │          │          │          │
-- └──────────┴──────────┴──────────┘
function layouts.three_col(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- First split: Create right 2/3 of screen (66%)
  main:split({ direction = 'Right', size = pct(66), cwd = cwd })
  -- Second split: Split the active (right) pane in half to create middle and right
  tab:active_pane():split({ direction = 'Right', size = pct(50), cwd = cwd })

  -- Set layout mode so Alt+N/Cmd+D continues the pattern
  set_layout_mode(tab, 'horizontal')
  tab:set_title('3col')
  return tab
end

-- ============================================================================
-- MONITORING LAYOUT: System monitoring with htop and logs
-- ============================================================================
-- WHY htop on top: System metrics are best viewed in wide format; htop uses
-- horizontal space for CPU/memory graphs and process columns.
--
-- WHY auto-start htop: This is the only layout that auto-starts commands
-- because monitoring is its dedicated purpose. Other layouts stay empty for
-- user flexibility.
--
-- USE CASE: Server monitoring, debugging performance issues, watching builds.
-- ┌────────────────────────────────┐
-- │             htop               │  <- system metrics
-- ├────────────────────────────────┤
-- │             logs               │  <- application logs
-- └────────────────────────────────┘
function layouts.monitor(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- Start htop in the top pane immediately
  main:send_text('htop\n')

  -- Create bottom pane (40% of height) for logs
  local logs = main:split({ direction = 'Bottom', size = pct(40), cwd = cwd })
  -- Provide a helpful hint for the logs pane
  logs:send_text('# tail -f your logs here\n')

  set_layout_mode(tab, 'vertical')
  tab:set_title('monitor')
  return tab
end

-- ============================================================================
-- QUAD LAYOUT: Four equal panes for parallel work
-- ============================================================================
-- WHY four equal panes: Each quadrant gets 25% of the screen, which on a
-- modern monitor is still enough for meaningful work.
--
-- USE CASE: Running multiple services simultaneously, comparing 4 files,
-- monitoring microservices, or pair programming scenarios.
-- ┌───────────────┬───────────────┐
-- │   top-left    │   top-right   │
-- ├───────────────┼───────────────┤
-- │  bottom-left  │  bottom-right │
-- └───────────────┴───────────────┘
function layouts.quad(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- Create right column (50% of width)
  local right = main:split({ direction = 'Right', size = pct(50), cwd = cwd })
  -- Split left column into top-left and bottom-left
  main:split({ direction = 'Bottom', size = pct(50), cwd = cwd })
  -- Split right column into top-right and bottom-right
  right:split({ direction = 'Bottom', size = pct(50), cwd = cwd })

  set_layout_mode(tab, 'tiled')
  tab:set_title('quad')
  return tab
end

-- ============================================================================
-- STACKED LAYOUT: Three horizontal rows
-- ============================================================================
-- WHY three rows: Useful when each task needs full width (like reading logs)
-- but you need to see multiple things at once.
--
-- MATH NOTE: Similar to three_col, we split 66% first, then 50% of that,
-- giving us three roughly equal rows.
--
-- USE CASE: Log monitoring, following multiple streams, or workflows where
-- width matters more than height (like git log output).
-- ┌────────────────────────────────┐
-- │              top               │
-- ├────────────────────────────────┤
-- │             middle             │
-- ├────────────────────────────────┤
-- │             bottom             │
-- └────────────────────────────────┘
function layouts.stacked(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- First split: bottom 66% of screen
  main:split({ direction = 'Bottom', size = pct(66), cwd = cwd })
  -- Second split: split the 66% in half to create middle and bottom rows
  tab:active_pane():split({ direction = 'Bottom', size = pct(50), cwd = cwd })

  set_layout_mode(tab, 'vertical')
  tab:set_title('stacked')
  return tab
end

-- ============================================================================
-- SIDE-BY-SIDE LAYOUT: Simple two-column split
-- ============================================================================
-- WHY: The most common split - comparing two files, code and docs, etc.
--
-- USE CASE: File comparison, side-by-side editing, or any two-pane workflow.
-- ┌───────────────┬───────────────┐
-- │               │               │
-- │     left      │     right     │
-- │               │               │
-- └───────────────┴───────────────┘
function layouts.side_by_side(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- Simple 50/50 horizontal split
  main:split({ direction = 'Right', size = pct(50), cwd = cwd })

  set_layout_mode(tab, 'horizontal')
  tab:set_title('split')
  return tab
end

-- ============================================================================
-- FOCUS LAYOUT: Maximum focus with minimal distraction
-- ============================================================================
-- WHY 75/25 split: The main pane dominates while keeping a small sidebar
-- for quick reference or monitoring.
--
-- USE CASE: Deep work sessions where you want to minimize distractions but
-- still have quick access to a terminal for occasional commands.
-- ┌────────────────────────┬──────┐
-- │                        │      │
-- │         main           │ side │  <- small sidebar
-- │                        │      │
-- └────────────────────────┴──────┘
function layouts.focus(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()

  -- Small 25% sidebar on the right - enough for a narrow terminal
  main:split({ direction = 'Right', size = pct(25), cwd = cwd })

  set_layout_mode(tab, 'main-vertical')
  tab:set_title('focus')
  return tab
end

-- ============================================================================
-- LAYOUT METADATA
-- ============================================================================
-- WHY separate metadata: Having layout metadata separate from the functions
-- allows us to build UI elements (fuzzy pickers, menus) without executing
-- the layout code. The 'id' maps to the function name in the layouts table.

local layout_list = {
  { id = 'dev',          name = 'Dev',          desc = 'Editor + terminal stack (60/40)' },
  { id = 'editor',       name = 'Editor',       desc = 'Full editor + bottom terminal' },
  { id = 'three_col',    name = '3 Column',     desc = 'Three equal columns' },
  { id = 'quad',         name = 'Quad',         desc = 'Four equal panes' },
  { id = 'stacked',      name = 'Stacked',      desc = 'Three horizontal rows' },
  { id = 'side_by_side', name = 'Side by Side', desc = 'Two vertical columns' },
  { id = 'focus',        name = 'Focus',        desc = 'Main pane + small sidebar' },
  { id = 'monitor',      name = 'Monitor',      desc = 'htop + logs' },
}

-- ============================================================================
-- LAYOUT APPLICATION HELPER
-- ============================================================================
-- WHY a helper function: Centralizes the logic for applying layouts, including
-- getting the current working directory and error handling.

-- Apply a layout by name
local function apply_layout(window, layout_name)
  local pane = window:active_pane()
  -- Get current working directory to pass to the new tab
  local cwd = pane:get_current_working_dir()
  local cwd_path = cwd and cwd.file_path or nil

  -- Look up the layout function and execute it
  if layouts[layout_name] then
    layouts[layout_name](window, cwd_path)
    wezterm.log_info('Applied layout: ' .. layout_name)
  else
    wezterm.log_error('Unknown layout: ' .. layout_name)
  end
end

-- ============================================================================
-- LAYOUT LAUNCHER BUILDER
-- ============================================================================
-- WHY dynamic building: Generates the fuzzy picker choices from layout_list,
-- ensuring the UI stays in sync with available layouts.

-- Build launcher entries for layouts (used by Cmd+Shift+L picker)
local function build_layout_launcher()
  local entries = {}
  for _, layout in ipairs(layout_list) do
    table.insert(entries, {
      label = layout.name .. ' - ' .. layout.desc,
      action = wezterm.action_callback(function(window, pane)
        apply_layout(window, layout.id)
      end),
    })
  end
  return entries
end

-- ============================================================================
-- PROJECT LAYOUTS (auto-apply layouts for specific directories/workspaces)
-- ============================================================================
-- WHY: Different projects have different needs. A web project might want the
-- dev layout by default, while a documentation project might want the editor
-- layout. This system lets you define those defaults.
--
-- HOW TO USE: Uncomment and modify the examples below. When you switch to a
-- workspace matching the pattern, the corresponding layout auto-applies.
--
-- PATTERNS: Use Lua string patterns (not regex). Common patterns:
-- - 'kit' matches any path containing 'kit'
-- - '^kit' matches paths starting with 'kit'
-- - 'kit$' matches paths ending with 'kit'
-- Simple pattern-to-layout mappings (uncomment and customize)
local project_layouts = {
  -- Pattern matching on workspace name or directory
  -- { pattern = 'kit',       layout = 'dev' },      -- Use dev layout for Kit project
  -- { pattern = 'lootbox',   layout = 'dev' },      -- Use dev layout for Lootbox
  -- { pattern = 'dotfiles',  layout = 'editor' },   -- Use editor layout for dotfiles
}

-- ============================================================================
-- CUSTOM PROJECT LAYOUT FUNCTIONS
-- ============================================================================
-- WHY: Sometimes you need more control than a simple layout mapping provides.
-- These functions can start specific commands, set up watchers, etc.
--
-- These override the simple mappings above when the pattern matches.
local project_layout_functions = {
  -- Example: Kit project with dev server and test watcher auto-started
  -- ['kit'] = function(window, cwd)
  --   local tab = window:mux_window():spawn_tab({ cwd = cwd })
  --   local main = tab:active_pane()
  --   -- Editor on left (60%)
  --   local right = main:split({ direction = 'Right', size = { Percent = 40 }, cwd = cwd })
  --   -- Dev server on top right - starts automatically
  --   right:send_text('pnpm dev\n')
  --   -- Tests on bottom right - starts automatically
  --   local tests = right:split({ direction = 'Bottom', size = { Percent = 50 }, cwd = cwd })
  --   tests:send_text('pnpm test --watch\n')
  --   tab:set_title('kit')
  --   return tab
  -- end,
}

-- ============================================================================
-- PROJECT LAYOUT LOOKUP
-- ============================================================================
-- WHY two types: The 'function' type is checked first (for complex setups),
-- then 'layout' type (for simple mappings). This allows overriding simple
-- mappings with custom functions.

-- Get layout for a workspace/directory
local function get_project_layout(workspace_name)
  -- Check custom functions first (higher priority)
  for pattern, _ in pairs(project_layout_functions) do
    if workspace_name:find(pattern) then
      return { type = 'function', pattern = pattern }
    end
  end
  -- Check simple mappings (lower priority)
  for _, mapping in ipairs(project_layouts) do
    if workspace_name:find(mapping.pattern) then
      return { type = 'layout', layout = mapping.layout }
    end
  end
  return nil  -- No project-specific layout found
end

-- Apply project layout based on workspace name
local function apply_project_layout(window, workspace_name, cwd)
  local project = get_project_layout(workspace_name)
  if not project then return false end  -- No matching project layout

  if project.type == 'function' then
    -- Execute the custom function
    project_layout_functions[project.pattern](window, cwd)
    return true
  elseif project.type == 'layout' then
    -- Apply the named layout
    layouts[project.layout](window, cwd)
    return true
  end
  return false
end

-- ============================================================================
-- WORKSPACE CHANGE EVENT (OPTIONAL)
-- ============================================================================
-- WHY commented out: Auto-applying layouts on workspace switch can be
-- surprising. Uncomment if you want this behavior.
--
-- HOW IT WORKS: When you switch workspaces (e.g., via smart_workspace_switcher),
-- this event fires and automatically applies the project layout if defined.
-- wezterm.on('workspace-switched', function(window, name, prev_name)
--   local pane = window:active_pane()
--   local cwd = pane:get_current_working_dir()
--   local cwd_path = cwd and cwd.file_path or nil
--   apply_project_layout(window, name, cwd_path)
-- end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Shorten cwd for display (shows last 2 path components)
-- WHY: Full paths are too long for titles. "~/dev/my-project" becomes "dev/my-project"
-- This gives enough context to distinguish directories without wasting space.
-- NOTE: Handles both Pane objects (method call) and PaneInformation tables (property access)
-- PaneInformation tables have strict metatables that error on unknown fields, so we use pcall
local function short_cwd(pane)
  local cwd
  -- Try method call first (Pane object), fallback to property (PaneInformation)
  local ok, result = pcall(function() return pane:get_current_working_dir() end)
  if ok and result then
    cwd = result
  else
    -- It's a PaneInformation table - use property access
    cwd = pane.current_working_dir
  end
  if not cwd then return "~" end  -- Fallback if cwd unavailable
  local home = os.getenv("HOME") or ""
  -- Replace home directory with ~ for readability
  local path = cwd.file_path:gsub(home, "~")
  -- Extract last two path components (e.g., "dev/my-project" from "~/dev/my-project")
  local last_two = path:match("([^/]+/[^/]+)$")
  return last_two or path:match("([^/]+)$") or path
end

-- ============================================================================
-- DYNAMIC COLOR SCHEME MAPPING
-- ============================================================================
-- WHY: Visual context helps identify which project you're in. Different colors
-- for different projects means you can instantly recognize which terminal
-- belongs to which workspace.
--
-- HOW TO USE: Add patterns and schemes below. The first matching pattern wins.
-- Patterns use Lua's string.find with plain=true (literal match, not regex).
-- Map cwd patterns to color schemes
local function scheme_for_cwd(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd or not cwd.file_path then return nil end
  local home = os.getenv("HOME") or ""
  -- Clean up the path (remove file:// prefix, normalize home dir)
  local path = cwd.file_path:gsub("^file://", ""):gsub(home, "~")
  
  -- Define your project-to-scheme mappings here
  -- Order matters: first match wins, so put specific paths before general ones
  -- NOTE: Scheme names have no spaces (e.g., "GruvboxDark" not "Gruvbox Dark")
  local mappings = {
    -- Add custom mappings here, e.g.:
    -- { pattern = "~/dev/special-project", scheme = "Catppuccin Mocha" },
    -- { pattern = "~/work", scheme = "Tokyo Night" },
  }
  
  -- Find first matching pattern
  for _, m in ipairs(mappings) do
    if path:find(m.pattern, 1, true) then  -- plain=true for literal matching
      return m.scheme
    end
  end
  return nil  -- No match, use default scheme
end

-- ============================================================================
-- PLUGINS
-- ============================================================================
-- WHY smart_workspace_switcher: This plugin integrates with zoxide (a smarter
-- 'cd' command) to provide fuzzy workspace switching. Press Cmd+O to see your
-- frequently-used directories and switch to them as workspaces.
--
-- WHAT IS ZOXIDE: zoxide tracks your directory usage and ranks them by
-- "frecency" (frequency + recency). It's installed via: brew install zoxide
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
-- Tell the plugin where to find zoxide binary (Homebrew location on macOS)
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

-- ============================================================================
-- PLUGIN: RESURRECT (Session Persistence)
-- ============================================================================
-- WHY: Without this, closing WezTerm loses all your tabs, panes, and layout.
-- Resurrect automatically saves and restores your workspace state.
--
-- USAGE:
--   Leader+S = Save current workspace state
--   Leader+R = Restore saved workspace state
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

-- ============================================================================
-- APPEARANCE CONFIGURATION
-- ============================================================================
-- These settings define the visual appearance of WezTerm.

-- COLOR SCHEME
-- WHY Gruvbox Dark: A warm, retro color scheme that's easy on the eyes for
-- long coding sessions. Popular in the terminal/vim community.
-- ALTERNATIVES: "Catppuccin Mocha", "Tokyo Night", "One Dark", "Dracula"
config.color_scheme = 'GruvboxDark'

-- FONT CONFIGURATION
-- WHY JetBrains Mono: Purpose-built for code with excellent ligatures,
-- clear distinctions between similar characters (0/O, 1/l/I), and
-- comfortable letter spacing.
-- ALTERNATIVES: "Fira Code", "Source Code Pro", "Hack", "Cascadia Code"
config.font = wezterm.font 'JetBrains Mono'
-- WHY 13pt: Large enough for comfortable reading without squinting,
-- small enough to fit meaningful content on screen
config.font_size = 13.0

-- ============================================================================
-- WINDOW CONFIGURATION
-- ============================================================================

-- WINDOW DECORATIONS
-- WHY "RESIZE" only: Removes the title bar for a cleaner look while keeping
-- resize handles. Title bar is redundant when using tabs.
-- OPTIONS: "FULL" (default macOS), "NONE" (no decorations), "RESIZE" (handles only)
config.window_decorations = "RESIZE"

-- WINDOW TRANSPARENCY (commented out by default)
-- WHY commented: Transparency can reduce readability and increase GPU usage.
-- Uncomment if you want to see your desktop through the terminal.
-- config.window_background_opacity = 0.50
-- config.macos_window_background_blur = 90  -- Blur effect for macOS

-- WINDOW PADDING
-- WHY padding: Small amount of space between content and window edges makes
-- text easier to read and looks more polished.
config.window_padding = {
  left = 10,   -- Space from left edge
  right = 10,  -- Space from right edge
  top = 10,    -- Space from top edge (below tab bar)
  bottom = 10, -- Space from bottom edge
}

-- ============================================================================
-- TAB BAR CONFIGURATION
-- ============================================================================
-- ALWAYS SHOW TAB BAR
-- WHY: Even with one tab, showing the bar provides context (workspace name,
-- current directory) and visual consistency. You always know where to look.
config.hide_tab_bar_if_only_one_tab = false

-- USE SIMPLE TAB BAR
-- WHY: The "fancy" tab bar looks like native macOS tabs but has limited
-- customization. The simple bar allows full control via format-tab-title event.
config.use_fancy_tab_bar = false

-- TAB BAR POSITION
-- WHY bottom: Popular placement that feels natural - content above, controls below.
-- Many terminal users prefer this from tmux/vim statusline conventions.
config.tab_bar_at_bottom = true

-- TAB WIDTH LIMIT
-- WHY 32 chars: Prevents long paths from making tabs too wide while allowing
-- enough text for meaningful identification.
config.tab_max_width = 32

-- ============================================================================
-- PANE VISUAL DISTINCTION
-- ============================================================================
-- INACTIVE PANE DIMMING
-- WHY: When you have multiple panes, it's crucial to know which one has focus.
-- Dimming inactive panes provides an instant visual cue.
-- BRIGHTNESS 0.3: Quite dim - makes the active pane really stand out.
-- Increase to 0.5-0.7 if you need to see inactive pane content better.
config.inactive_pane_hsb = {
  -- saturation = 0.9,  -- Uncomment to desaturate colors too
  brightness = 0.3,     -- 30% brightness (quite dim)
}

-- PANE SPLIT LINE COLOR
-- WHY purple: Catppuccin Mauve provides good contrast against both light and
-- dark backgrounds, making split lines visible without being distracting.
config.colors = {
  split = '#cba6f7',  -- Catppuccin Mauve - visible purple split lines
}

-- ============================================================================
-- PERFORMANCE CONFIGURATION
-- ============================================================================
-- IMPORTANT: These settings impact battery life and system resources.
-- The defaults are conservative to prevent issues on various systems.
-- GPU BACKEND (commented out)
-- WHY commented: WebGpu can provide smoother rendering but may cause high GPU
-- usage on some systems. The default backend is usually fine.
-- UNCOMMENT if you want to experiment: config.front_end = "WebGpu"
-- config.front_end = "WebGpu"

-- FRAME RATE (commented out)
-- WHY commented: High FPS (120) causes constant GPU work even when idle,
-- which drains battery on laptops. Default (60) is plenty for terminals.
-- UNCOMMENT only if you notice tearing: config.max_fps = 120
-- config.max_fps = 120

-- ============================================================================
-- CURSOR CONFIGURATION
-- ============================================================================
-- CURSOR STYLE
-- WHY SteadyBar: A thin vertical bar is less distracting than a block cursor
-- and is familiar to users of modern text editors (VS Code, etc.).
-- WHY not blinking: Blinking cursors cause constant screen redraws, which
-- can impact battery life and is visually distracting.
-- ALTERNATIVE: Uncomment below for blinking bar:
-- config.default_cursor_style = 'BlinkingBar'
-- config.cursor_blink_rate = 500  -- milliseconds between blinks
config.default_cursor_style = 'SteadyBar'

-- ============================================================================
-- LEADER KEY CONFIGURATION
-- ============================================================================
-- WHY a leader key: Following tmux conventions, many commands require a
-- "prefix" key combination. This avoids conflicts with application shortcuts
-- and provides a consistent command entry point.
--
-- HOW IT WORKS: Press Ctrl+Q, then press the next key within 2 seconds.
-- Example: Ctrl+Q, then h to move focus left.
--
-- WHY Ctrl+Q: It's a common choice (tmux uses Ctrl+B by default), and Q is
-- easy to reach. Some people prefer Ctrl+A (like screen) or Ctrl+Space.
config.leader = { key = 'q', mods = 'CTRL', timeout_milliseconds = 2000 }

-- ============================================================================
-- KEYBINDINGS
-- ============================================================================
-- This config provides multiple "layers" of keybindings:
-- 1. CMD+key: macOS-native shortcuts (Cmd+W, Cmd+D, Cmd+T, etc.)
-- 2. LEADER+key: tmux-style commands (Ctrl+Q, then key)
-- 3. ALT+key: Zellij-style commands (Alt+n, Alt+h/j/k/l, etc.)
--
-- This layering lets you use whichever style you're most comfortable with.
config.keys = {
  -- ============================================================================
  -- MACOS-NATIVE SHORTCUTS (Cmd+key)
  -- ============================================================================
  -- These follow macOS conventions and work like other Mac apps.
  
  -- CLOSE PANE: Cmd+W
  -- WHY no confirm: Speed over safety. If you're used to Cmd+W closing things,
  -- you expect immediate action. Use Cmd+Z in many apps to undo, though not here.
  {
    mods = "CMD",
    key = "w",
    action = act.CloseCurrentPane { confirm = false },
  },

  -- ============================================================================
  -- NEW TAB WITH ZOXIDE PICKER: Cmd+T
  -- ============================================================================
  -- WHY: Standard Cmd+T creates a new tab, but we enhance it by immediately
  -- showing a zoxide directory picker. This lets you jump to frequently-used
  -- directories in one smooth motion instead of: new tab → cd → type path.
  {
    mods = "CMD",
    key = "t",
    action = wezterm.action_callback(function(window, pane)
      -- Spawn a new tab first
      local tab, new_pane, _ = window:mux_window():spawn_tab({})

      -- Schedule the picker to appear after the tab is ready
      -- WHY 0.001 delay: Gives WezTerm time to finish tab creation
      wezterm.time.call_after(0.001, function()
        -- Run zoxide query to get ranked directory list
        local success, stdout = wezterm.run_child_process({ '/opt/homebrew/bin/zoxide', 'query', '-l' })
        if not success then return end

        -- Build the fuzzy picker choices
        local choices = {}
        for line in stdout:gmatch('[^\n]+') do
          local home = os.getenv("HOME") or ""
          -- Display paths with ~ for home directory (more readable)
          local display = line:gsub("^" .. home, "~")
          table.insert(choices, { id = line, label = display })
        end

        -- Show the fuzzy directory picker
        window:perform_action(
          act.InputSelector {
            title = 'Select directory for new tab',
            choices = choices,
            fuzzy = true,  -- Enable fuzzy matching (type to filter)
            action = wezterm.action_callback(function(win, _, id, label)
              if id then
                -- cd to selected directory and clear the screen
                new_pane:send_text('cd ' .. wezterm.shell_quote_arg(id) .. ' && clear\n')
              end
            end),
          },
          new_pane
        )
      end)
    end),
  },

  -- ============================================================================
  -- SMART TAB/DIRECTORY PICKER: Cmd+P
  -- ============================================================================
  -- WHY: Zoxide-powered unified picker. Shows your frecent directories and
  -- intelligently switches to existing tabs or opens new ones.
  --
  -- BEHAVIOR:
  -- 1. Shows zoxide directories (frecency-ranked)
  -- 2. Green "●" = tab already open at this dir (will switch to it)
  -- 3. Blue "○" = no tab open (will create new tab)
  -- 4. Select any entry -> switches if tab exists, opens new if not
  --
  -- THEMING: Uses Catppuccin Mocha colors for visual polish
  {
    mods = "CMD",
    key = "p",
    action = wezterm.action_callback(function(window, pane)
      local home = os.getenv("HOME") or ""
      local tabs = window:mux_window():tabs()

      -- Gruvbox Dark colors
      local green = "#b8bb26"   -- Open tab indicator (gruvbox green)
      local yellow = "#fabd2f"  -- New tab indicator (gruvbox yellow)
      local aqua = "#8ec07c"    -- Directory path (gruvbox aqua)
      local gray = "#928374"    -- Dimmed text (gruvbox gray)

      -- Build a map of directories that have open tabs
      -- Maps: directory path -> { tab = tab_object, tab_id = id }
      local open_dirs = {}
      for _, t in ipairs(tabs) do
        for _, p in ipairs(t:panes()) do
          local cwd = p:get_current_working_dir()
          if cwd and cwd.file_path then
            open_dirs[cwd.file_path] = { tab = t, tab_id = t:tab_id() }
          end
        end
      end

      -- Get zoxide directories
      local success, stdout, stderr = wezterm.run_child_process({ '/opt/homebrew/bin/zoxide', 'query', '-l' })
      if not success then
        wezterm.log_error("zoxide failed: " .. tostring(stderr))
        return
      end

      local choices = {}
      for line in stdout:gmatch('[^\n]+') do
        local display = line:gsub("^" .. home, "~")
        local is_open = open_dirs[line] ~= nil

        -- Format with colors: "● ~/path" (green) or "○ ~/path" (yellow)
        local label = wezterm.format({
          { Foreground = { Color = is_open and green or yellow } },
          { Text = is_open and "● " or "○ " },
          { Foreground = { Color = aqua } },
          { Text = display },
        })

        table.insert(choices, { id = line, label = label })
      end

      -- Show the picker with styled description
      window:perform_action(
        act.InputSelector({
          title = wezterm.format({
            { Foreground = { Color = aqua } },
            { Attribute = { Intensity = "Bold" } },
            { Text = "󰍉  Quick Open" },
          }),
          description = wezterm.format({
            { Foreground = { Color = green } },
            { Text = "●" },
            { Foreground = { Color = gray } },
            { Text = " switch to tab  " },
            { Foreground = { Color = yellow } },
            { Text = "○" },
            { Foreground = { Color = gray } },
            { Text = " open new tab" },
          }),
          fuzzy_description = wezterm.format({
            { Foreground = { Color = yellow } },
            { Attribute = { Intensity = "Bold" } },
            { Text = "󰈞 Search: " },
          }),
          choices = choices,
          fuzzy = true,
          action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
            if not id then return end  -- User cancelled

            -- Check if a tab is already open at this directory
            local existing = open_dirs[id]
            if existing then
              -- Switch to existing tab
              existing.tab:activate()
            else
              -- Open new tab at this directory
              inner_window:mux_window():spawn_tab({ cwd = id })
            end
          end),
        }),
        pane
      )
    end),
  },

  -- ============================================================================
  -- WORKSPACE AND PANE NAVIGATION
  -- ============================================================================
  
  -- FUZZY WORKSPACE PICKER: Cmd+Shift+S
  -- WHY: Quick access to all workspaces with fuzzy search
  { mods = "CMD|SHIFT", key = "s", action = act.ShowLauncherArgs { flags = "FUZZY|WORKSPACES" } },
  
  -- SMART WORKSPACE SWITCHER: Cmd+O
  -- WHY: Opens zoxide-powered workspace switcher from the plugin
  -- This is the primary way to switch between project workspaces
  { mods = "CMD", key = "o", action = workspace_switcher.switch_workspace() },
  
  -- PANE SELECTOR: Cmd+E
  -- WHY: Shows number overlays on each pane for quick switching
  -- Press Cmd+E, then type the number to focus that pane
  { mods = "CMD", key = "e", action = act.PaneSelect { alphabet = "1234567890", mode = "Activate" } },
  
  -- SWAP PANES: Cmd+Shift+E
  -- WHY: Rearrange pane positions by swapping with selected pane
  { mods = "CMD|SHIFT", key = "e", action = act.PaneSelect { alphabet = "1234567890", mode = "SwapWithActive" } },

  -- ============================================================================
  -- PANE SPLITTING (LEADER KEY)
  -- ============================================================================
  -- These follow tmux conventions for users familiar with that workflow.
  
  -- SPLIT HORIZONTAL: Leader + - (dash)
  -- WHY dash: Visual mnemonic - a dash is horizontal
  { mods = "LEADER", key = "-", action = act.SplitVertical { domain = "CurrentPaneDomain" } },
  
  -- SPLIT VERTICAL: Leader + | (pipe)
  -- WHY pipe: Visual mnemonic - a pipe is vertical
  { mods = "LEADER", key = "|", action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },
  
  -- SMART SPLIT: Cmd+D
  -- WHY: Uses the smart layout system instead of always splitting right.
  -- Respects the current layout mode (tiled, main-vertical, etc.)
  {
    mods = "CMD",
    key = "d",
    action = wezterm.action_callback(function(window, pane)
      smart_new_pane(window, pane)
    end),
  },
  
  -- SIMPLE SPLIT DOWN: Cmd+Shift+D
  -- WHY: Sometimes you just want a vertical split regardless of layout mode.
  -- This bypasses the smart layout system for manual control.
  {
    mods = "CMD|SHIFT",
    key = "d",
    action = act.SplitVertical { domain = "CurrentPaneDomain" },
  },

  -- ============================================================================
  -- COMMAND PALETTE AND LAUNCHER
  -- ============================================================================
  
  -- COMMAND PALETTE: Cmd+K
  -- WHY: VS Code-style access to all WezTerm commands
  { mods = "CMD", key = "k", action = act.ActivateCommandPalette },
  
  -- LAUNCHER MENU: Cmd+L
  -- WHY: Quick access to profiles, SSH hosts, etc.
  { mods = "CMD", key = "l", action = act.ShowLauncher },

  -- ============================================================================
  -- PANE NAVIGATION (LEADER KEY + VIM KEYS)
  -- ============================================================================
  -- tmux-style navigation using Leader + h/j/k/l
  { mods = "LEADER", key = "h", action = act.ActivatePaneDirection "Left" },
  { mods = "LEADER", key = "j", action = act.ActivatePaneDirection "Down" },
  { mods = "LEADER", key = "k", action = act.ActivatePaneDirection "Up" },
  { mods = "LEADER", key = "l", action = act.ActivatePaneDirection "Right" },

  -- CLOSE PANE: Leader + X (with confirmation)
  -- WHY confirm: Leader+x is less common than Cmd+W, so we add safety
  { mods = "LEADER", key = "x", action = act.CloseCurrentPane { confirm = true } },

  -- ============================================================================
  -- TAB MANAGEMENT (LEADER KEY)
  -- ============================================================================
  
  -- NEW TAB: Leader + C
  -- WHY 'c': tmux convention (create)
  { mods = "LEADER", key = "c", action = act.SpawnTab "CurrentPaneDomain" },
  
  -- NEXT TAB: Leader + N
  { mods = "LEADER", key = "n", action = act.ActivateTabRelative(1) },
  
  -- PREVIOUS TAB: Leader + P
  { mods = "LEADER", key = "p", action = act.ActivateTabRelative(-1) },

  -- QUICK TAB SWITCHING: Leader + Number
  -- WHY: Direct access to tabs 1-5 (zero-indexed internally)
  { mods = "LEADER", key = "1", action = act.ActivateTab(0) },
  { mods = "LEADER", key = "2", action = act.ActivateTab(1) },
  { mods = "LEADER", key = "3", action = act.ActivateTab(2) },
  { mods = "LEADER", key = "4", action = act.ActivateTab(3) },
  { mods = "LEADER", key = "5", action = act.ActivateTab(4) },

  -- ZOOM PANE: Leader + Z
  -- WHY: Toggle fullscreen for current pane (tmux-style)
  -- Useful for temporarily focusing on one pane
  { mods = "LEADER", key = "z", action = act.TogglePaneZoomState },

  -- COPY MODE: Leader + [
  -- WHY: tmux-style scrollback/copy mode entry
  -- Navigate with vim keys, select with v, yank with y
  { mods = "LEADER", key = "[", action = act.ActivateCopyMode },

  -- ============================================================================
  -- ZELLIJ-STYLE AUTO-LAYOUT (ALT KEY)
  -- ============================================================================
  -- These keybindings replicate Zellij's workflow using Alt as the modifier.
  
  -- SMART NEW PANE: Alt+N
  -- WHY: Creates a new pane using the current layout mode's logic
  -- This is the main way to add panes when using the auto-layout system
  {
    mods = "ALT",
    key = "n",
    action = wezterm.action_callback(function(window, pane)
      smart_new_pane(window, pane)
    end),
  },

  -- CYCLE LAYOUT MODE FORWARD: Alt+]
  -- WHY: Quickly cycle through layout modes to find the one you want
  -- Shows a toast notification with the new mode name
  {
    mods = "ALT",
    key = "]",
    action = wezterm.action_callback(function(window, pane)
      local tab = window:active_tab()
      local current = get_layout_mode(tab)
      local new_mode = cycle_layout_mode(current, 1)  -- +1 = forward
      
      -- Use centralized setter (avoids drift)
      set_layout_mode(tab, new_mode)
      
      -- Find human-readable name for the toast notification
      local mode_name = new_mode
      for _, m in ipairs(LAYOUT_MODES) do
        if m.id == new_mode then mode_name = m.name .. ' - ' .. m.desc break end
      end
      
      window:toast_notification('WezTerm', 'Layout: ' .. mode_name, nil, 2000)
    end),
  },

  -- CYCLE LAYOUT MODE BACKWARD: Alt+[
  -- WHY: Go the other direction in case you overshoot
  {
    mods = "ALT",
    key = "[",
    action = wezterm.action_callback(function(window, pane)
      local tab = window:active_tab()
      local current = get_layout_mode(tab)
      local new_mode = cycle_layout_mode(current, -1)  -- -1 = backward
      
      set_layout_mode(tab, new_mode)
      
      local mode_name = new_mode
      for _, m in ipairs(LAYOUT_MODES) do
        if m.id == new_mode then mode_name = m.name .. ' - ' .. m.desc break end
      end
      
      window:toast_notification('WezTerm', 'Layout: ' .. mode_name, nil, 2000)
    end),
  },

  -- LAYOUT MODE PICKER: Alt+Space
  -- WHY: Fuzzy picker for directly selecting a layout mode
  -- Useful when you know which mode you want without cycling
  {
    mods = "ALT",
    key = "Space",
    action = wezterm.action.InputSelector({
      title = "Select Layout Mode (Zellij-style)",
      -- Build choices from LAYOUT_MODES at config load time
      choices = (function()
        local choices = {}
        for _, mode in ipairs(LAYOUT_MODES) do
          table.insert(choices, {
            id = mode.id,
            label = mode.name .. ' - ' .. mode.desc,
          })
        end
        return choices
      end)(),
      action = wezterm.action_callback(function(window, pane, id, label)
        if id then
          local tab = window:active_tab()
          set_layout_mode(tab, id)
          window:toast_notification('WezTerm', 'Layout: ' .. label, nil, 2000)
        end
      end),
    }),
  },

  -- ROTATE PANES: Alt+R
  -- WHY: Cycle pane positions clockwise - useful for rearranging after
  -- panes are created in the wrong order
  {
    mods = "ALT",
    key = "r",
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(act.RotatePanes "Clockwise", pane)
    end),
  },

  -- RESET ZOOM: Alt+=
  -- WHY: WezTerm doesn't have native pane equalization like tmux.
  -- This just ensures no pane is zoomed, as a "reset" of sorts.
  -- For manual balancing, use Alt+Shift+h/j/k/l to resize.
  {
    mods = "ALT",
    key = "=",
    action = act.SetPaneZoomState(false),
  },

  -- FOCUS EXPAND: Alt+Enter
  -- WHY: Make the focused pane larger without full zoom
  -- Expands focused pane in all directions for more working room
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

  -- FOCUS SHRINK: Alt+Backspace
  -- WHY: Opposite of expand - shrink focused pane to give others more room
  {
    mods = "ALT",
    key = "Backspace",
    action = act.Multiple({
      act.SetPaneZoomState(false),
      act.AdjustPaneSize { "Left", -15 },
      act.AdjustPaneSize { "Right", -15 },
      act.AdjustPaneSize { "Up", -8 },
      act.AdjustPaneSize { "Down", -8 },
    }),
  },

  -- ============================================================================
  -- ZELLIJ-STYLE PANE NAVIGATION (ALT + VIM KEYS)
  -- ============================================================================
  -- WHY Alt+hjkl: Zellij uses Alt as its primary modifier, making pane
  -- navigation instantly accessible without a leader key prefix.
  { mods = "ALT", key = "h", action = act.ActivatePaneDirection "Left" },
  { mods = "ALT", key = "j", action = act.ActivatePaneDirection "Down" },
  { mods = "ALT", key = "k", action = act.ActivatePaneDirection "Up" },
  { mods = "ALT", key = "l", action = act.ActivatePaneDirection "Right" },

  -- ============================================================================
  -- ZELLIJ-STYLE PANE RESIZING (ALT+SHIFT + VIM KEYS)
  -- ============================================================================
  -- WHY Alt+Shift: Shift is the "bigger/more" modifier, so Alt+Shift+hjkl
  -- does the "bigger" version of navigation: resizing.
  -- 5 is the number of cells to resize by each press.
  { mods = "ALT|SHIFT", key = "h", action = act.AdjustPaneSize { "Left", 5 } },
  { mods = "ALT|SHIFT", key = "j", action = act.AdjustPaneSize { "Down", 5 } },
  { mods = "ALT|SHIFT", key = "k", action = act.AdjustPaneSize { "Up", 5 } },
  { mods = "ALT|SHIFT", key = "l", action = act.AdjustPaneSize { "Right", 5 } },

  -- TOGGLE FLOATING/ZOOM: Alt+F
  -- WHY: Zellij has floating panes; WezTerm doesn't, so we use zoom as a
  -- substitute. This toggles the current pane to/from fullscreen.
  {
    mods = "ALT",
    key = "f",
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(act.TogglePaneZoomState, pane)
    end),
  },

  -- CLOSE PANE: Alt+X
  -- WHY: Quick pane closing without confirmation (Zellij-style speed)
  {
    mods = "ALT",
    key = "x",
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(act.CloseCurrentPane { confirm = false }, pane)
    end),
  },

  -- ============================================================================
  -- DIRECT PANE SWITCHING (CMD + NUMBER)
  -- ============================================================================
  -- WHY: In addition to Cmd+E's overlay selector, direct number access is
  -- faster when you know which pane you want (1-9).
  { mods = "CMD", key = "1", action = act.ActivatePaneByIndex(0) },
  { mods = "CMD", key = "2", action = act.ActivatePaneByIndex(1) },
  { mods = "CMD", key = "3", action = act.ActivatePaneByIndex(2) },
  { mods = "CMD", key = "4", action = act.ActivatePaneByIndex(3) },
  { mods = "CMD", key = "5", action = act.ActivatePaneByIndex(4) },
  { mods = "CMD", key = "6", action = act.ActivatePaneByIndex(5) },
  { mods = "CMD", key = "7", action = act.ActivatePaneByIndex(6) },
  { mods = "CMD", key = "8", action = act.ActivatePaneByIndex(7) },
  { mods = "CMD", key = "9", action = act.ActivatePaneByIndex(8) },

  -- ============================================================================
  -- STATIC LAYOUT TEMPLATES (CMD+SHIFT+L AND LEADER+SHIFT+KEY)
  -- ============================================================================
  -- LAYOUT PICKER: Cmd+Shift+L
  -- WHY: Opens a fuzzy picker with all available static layouts
  -- Select one to create a new tab with that layout applied
  {
    mods = "CMD|SHIFT",
    key = "l",
    action = wezterm.action.InputSelector({
      title = "Select Layout",
      choices = (function()
        local choices = {}
        for _, layout in ipairs(layout_list) do
          table.insert(choices, {
            id = layout.id,
            label = layout.name .. ' - ' .. layout.desc,
          })
        end
        return choices
      end)(),
      action = wezterm.action_callback(function(window, pane, id, label)
        if id then
          apply_layout(window, id)
        end
      end),
    }),
  },

  -- QUICK LAYOUT HOTKEYS: Leader+Shift+<key>
  -- WHY: Direct access to specific layouts without opening the picker
  -- Useful when you know exactly which layout you want
  { mods = "LEADER|SHIFT", key = "d", action = wezterm.action_callback(function(w, p) apply_layout(w, 'dev') end) },
  { mods = "LEADER|SHIFT", key = "e", action = wezterm.action_callback(function(w, p) apply_layout(w, 'editor') end) },
  { mods = "LEADER|SHIFT", key = "3", action = wezterm.action_callback(function(w, p) apply_layout(w, 'three_col') end) },
  { mods = "LEADER|SHIFT", key = "4", action = wezterm.action_callback(function(w, p) apply_layout(w, 'quad') end) },
  { mods = "LEADER|SHIFT", key = "s", action = wezterm.action_callback(function(w, p) apply_layout(w, 'stacked') end) },
  { mods = "LEADER|SHIFT", key = "v", action = wezterm.action_callback(function(w, p) apply_layout(w, 'side_by_side') end) },
  { mods = "LEADER|SHIFT", key = "f", action = wezterm.action_callback(function(w, p) apply_layout(w, 'focus') end) },
  { mods = "LEADER|SHIFT", key = "m", action = wezterm.action_callback(function(w, p) apply_layout(w, 'monitor') end) },

  -- ============================================================================
  -- POWER USER FEATURES
  -- ============================================================================

  -- SESSION PERSISTENCE: Leader+S / Leader+R
  -- WHY: Save your entire workspace layout before closing, restore it later
  {
    mods = "LEADER",
    key = "s",
    action = wezterm.action_callback(function(win, pane)
      resurrect.save_state(resurrect.workspace_state.get_workspace_state())
      win:toast_notification('WezTerm', 'Workspace saved', nil, 1000)
    end),
  },

  -- QUICK SELECT: Leader+Space
  -- WHY: Highlights all URLs, hashes, IPs on screen. Type the label to copy.
  -- Game-changer for copying git hashes, URLs, etc. without using the mouse.
  { mods = "LEADER", key = "Space", action = act.QuickSelect },

  -- PROMOTE PANE: Leader+Enter
  -- WHY: In main layouts, quickly swap any pane with the main (largest) pane
  -- Useful for "promoting" a terminal from the stack to the editor position
  { mods = "LEADER", key = "Enter", action = act.PaneSelect { mode = "SwapWithActive" } },

  -- SCROLLBACK SEARCH: Cmd+F
  -- WHY: Direct access to search without entering copy mode first
  { mods = "CMD", key = "f", action = act.Search 'CurrentSelectionOrEmptyString' },

  -- ZEN MODE TOGGLE: Leader+Z (overrides pane zoom)
  -- WHY: Sometimes you want zero distractions - hide tab bar, remove padding
  -- NOTE: This replaces the default Leader+Z zoom. Use Alt+F for pane zoom instead.
  {
    mods = "LEADER",
    key = "z",
    action = wezterm.action_callback(function(window, pane)
      local overrides = window:get_config_overrides() or {}
      if overrides.enable_tab_bar == false then
        -- Exit Zen Mode: restore tab bar and padding
        overrides.enable_tab_bar = true
        overrides.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
        window:toast_notification('WezTerm', 'Zen Mode OFF', nil, 1000)
      else
        -- Enter Zen Mode: hide tab bar, remove padding
        overrides.enable_tab_bar = false
        overrides.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
        window:toast_notification('WezTerm', 'Zen Mode ON', nil, 1000)
      end
      window:set_config_overrides(overrides)
    end),
  },

  -- SMART SCROLLBACK CLEAR: Cmd+K (Vim-aware)
  -- WHY: Cmd+K normally clears scrollback, but in Neovim it would break the UI.
  -- This version passes through to Vim, only clears in regular shell.
  {
    mods = "CMD",
    key = "k",
    action = wezterm.action_callback(function(window, pane)
      if is_vim(pane) then
        -- In Vim: pass the key through
        window:perform_action(act.SendKey({ key = 'k', mods = 'CMD' }), pane)
      else
        -- In shell: clear scrollback and redraw prompt
        window:perform_action(act.ClearScrollback 'ScrollbackOnly', pane)
        window:perform_action(act.SendKey({ key = 'L', mods = 'CTRL' }), pane)
      end
    end),
  },
}  -- End of config.keys

-- ============================================================================
-- KEY TABLES (MODAL KEYBINDINGS)
-- ============================================================================
-- WHY: Holding Alt+Shift+h repeatedly to resize is ergonomically painful.
-- Key Tables let you enter a "mode" where single keys perform actions.
--
-- RESIZE MODE: Press Leader+R to enter, then use h/j/k/l freely to resize.
-- Press Escape to exit. Much more comfortable for fine-grained adjustments.

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

-- Add the resize mode activation key (must be done after config.keys is defined)
table.insert(config.keys, {
  mods = "LEADER",
  key = "r",
  action = act.ActivateKeyTable { name = 'resize_pane', one_shot = false },
})

-- ============================================================================
-- HYPERLINK RULES
-- ============================================================================
-- WHY: Make URLs, emails, and custom patterns Cmd+clickable.
-- Much faster than selecting and copying manually.

config.hyperlink_rules = {
  -- Standard URLs (http, https, ftp, file, mailto, ssh, git)
  { regex = '\\b\\w+://[\\w.-]+\\.[a-z]{2,15}\\S*\\b', format = '$0' },
  
  -- Email addresses
  { regex = '\\b[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+\\b', format = 'mailto:$0' },
  
  -- File paths (starting with / or ~)
  { regex = '\\b(/[\\w.-]+)+/?\\b', format = 'file://$0' },
  
  -- GitHub-style issue/PR references (uncomment and customize for your repos)
  -- { regex = '#(\\d+)', format = 'https://github.com/YOUR-ORG/YOUR-REPO/issues/$1' },
  -- { regex = 'gh-(\\d+)', format = 'https://github.com/YOUR-ORG/YOUR-REPO/issues/$1' },
}

-- ============================================================================
-- VISUAL BELL (No Audio)
-- ============================================================================
-- WHY: System beeps are annoying, especially in quiet environments or with
-- headphones. Visual bell provides feedback without sound.

config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_duration_ms = 75,
  fade_out_duration_ms = 75,
  target = 'CursorColor',  -- Flash the cursor instead of the whole screen
}

-- ============================================================================
-- DYNAMIC THEME (MACOS APPEARANCE)
-- ============================================================================
-- WHY: macOS can switch between light and dark mode automatically. This
-- function returns an appropriate color scheme based on the current setting.
--
-- COMMENTED OUT by default because a single scheme (Gruvbox Dark) is used.
local function scheme_for_appearance(appearance)
  -- Check if the appearance contains "Dark" (e.g., "Dark" or "LightDark")
  if appearance:find("Dark") then
    return "Catppuccin Mocha"  -- Dark theme
  else
    return "Catppuccin Latte"   -- Light theme
  end
end

-- ENABLE DYNAMIC THEME: Uncomment this line to follow macOS appearance
-- This will switch between Catppuccin Mocha (dark) and Latte (light)
-- config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())

-- ============================================================================
-- PLUGIN INITIALIZATION
-- ============================================================================
-- Apply plugin configurations to the config object
workspace_switcher.apply_to_config(config)

-- ============================================================================
-- CUSTOM TAB TITLES
-- ============================================================================
-- WHY custom titles: Default titles are often unhelpful (just "zsh" or blank).
-- Custom titles show directory + process + activity indicators, making tabs
-- much more useful when you have many open.
--
-- FORMAT: [indicators] process · full_path
-- INDICATORS:
--   ● = Unseen output (activity in background tab)
--   🔍 = Pane is zoomed (fullscreen)
--
-- Both process and path are searchable via Cmd+P fuzzy finder.
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane
  local cwd = pane.current_working_dir
  local home = os.getenv("HOME") or ""

  -- Get full path (replacing home dir with ~)
  local full_path = "~"
  if cwd and cwd.file_path then
    full_path = cwd.file_path:gsub("^" .. home, "~")
  end

  -- Get the foreground process name (what's actually running in the pane)
  local process = pane.foreground_process_name or ""
  process = process:match("([^/]+)$") or process  -- Extract basename
  if process == "" then process = "shell" end      -- Fallback for empty

  -- UNSEEN OUTPUT INDICATOR
  -- WHY: When a background tab has new output, you want to know without
  -- switching to it. The ● dot is a visual "notification badge".
  local indicator = ""
  for _, p in ipairs(tab.panes) do
    if p.has_unseen_output then
      indicator = "● "
      break
    end
  end

  -- ZOOMED PANE INDICATOR
  -- WHY: Remind yourself that a pane is zoomed (might explain why you
  -- can't see other panes in this tab)
  local zoom = ""
  if tab.active_pane.is_zoomed then
    zoom = "🔍 "
  end

  -- Build the title: " ● 🔍 nvim · ~/dev/project "
  local title = string.format(" %s%s%s · %s ", indicator, zoom, process, full_path)

  -- CATPPUCCIN MOCHA COLORS
  -- Active tab: Lighter background (Surface0), bright text
  -- Inactive tab: Darker background (Base), dimmed text
  if tab.is_active then
    return {
      { Background = { Color = '#313244' } },  -- Surface0 (slightly lighter)
      { Foreground = { Color = '#cdd6f4' } },  -- Text (bright)
      { Text = title },
    }
  end
  return {
    { Background = { Color = '#1e1e2e' } },    -- Base (dark)
    { Foreground = { Color = '#6c7086' } },    -- Overlay0 (dimmed)
    { Text = title },
  }
end)

-- ============================================================================
-- WINDOW TITLE
-- ============================================================================
-- WHY: When you have multiple WezTerm windows, the title helps identify them
-- in the app switcher and dock. Shows the current directory (shortened).
wezterm.on('format-window-title', function(tab, pane, tabs, panes, cfg)
  -- Use the short_cwd helper to get a compact path representation
  return short_cwd(pane)
end)

-- ============================================================================
-- STATUS BAR (RIGHT SIDE)
-- ============================================================================
-- WHY: The status bar provides at-a-glance information without cluttering
-- the terminal content. Shows:
--   - Mode indicator (copy mode, search mode, etc.) - RED
--   - Leader key indicator (when Ctrl+Q is pressed) - PEACH/ORANGE
--   - Layout mode (tiled/vertical/etc. with icon) - PURPLE
--   - Workspace name - BLUE
--   - Current working directory - GRAY
--   - Time - DARK GRAY
--
-- LEFT STATUS is disabled (removed hostname display)
wezterm.on("update-status", function(window, pane)
  -- DYNAMIC COLOR SCHEME BASED ON CWD
  -- Check if the current directory has a custom color scheme mapping
  -- NOTE: Only update if scheme changes to avoid visual flashing during picker use
  local scheme = scheme_for_cwd(pane)
  local current_overrides = window:get_config_overrides() or {}
  local current_scheme = current_overrides.color_scheme

  if scheme and scheme ~= current_scheme then
    -- Override the color scheme for this window based on directory
    window:set_config_overrides({ color_scheme = scheme })
  elseif not scheme and current_scheme then
    -- Clear scheme override only if we had one before
    window:set_config_overrides({})
  end
  -- If no scheme and no current override, do nothing (avoid flash)

  -- DISABLE LEFT STATUS BAR
  -- WHY: The hostname (e.g., "johns") isn't useful in most local setups
  -- and wastes space. Remove this line to re-enable hostname display.
  window:set_left_status("")

  -- BUILD RIGHT STATUS BAR
  -- We build an array of formatting directives that WezTerm renders
  local cells = {}

  -- MODE INDICATOR (copy mode, search mode, etc.)
  -- WHY: When you're in a special mode, you need to know to exit correctly
  local mode = window:active_key_table()
  if mode then
    table.insert(cells, { Foreground = { Color = "#f38ba8" } })  -- Red/Pink
    table.insert(cells, { Attribute = { Intensity = "Bold" } })
    table.insert(cells, { Text = " " .. mode:upper() .. " │" })
    table.insert(cells, { Attribute = { Intensity = "Normal" } })
  end

  -- LEADER KEY INDICATOR
  -- WHY: When you press Ctrl+Q (leader), you need visual confirmation
  -- that WezTerm is waiting for the next key
  if window:leader_is_active() then
    table.insert(cells, { Foreground = { Color = "#fab387" } })  -- Peach/Orange
    table.insert(cells, { Attribute = { Intensity = "Bold" } })
    table.insert(cells, { Text = " LEADER │" })
    table.insert(cells, { Attribute = { Intensity = "Normal" } })
  end

  -- LAYOUT MODE INDICATOR (Zellij-style)
  -- WHY: Reminds you which layout mode is active for this tab
  -- Each mode has an icon for quick visual identification
  local tab = window:active_tab()
  local layout_mode = get_layout_mode(tab)
  local layout_icon = ({
    ['tiled'] = '⊞',            -- Grid icon
    ['vertical'] = '⬍',         -- Vertical arrows
    ['horizontal'] = '⬌',       -- Horizontal arrows
    ['main-vertical'] = '◧',    -- Left-heavy box
    ['main-horizontal'] = '⬒',  -- Top-heavy box
  })[layout_mode] or '⊞'
  table.insert(cells, { Foreground = { Color = "#cba6f7" } })  -- Mauve/Purple
  table.insert(cells, { Text = " " .. layout_icon .. " " .. layout_mode })

  -- WORKSPACE NAME
  -- WHY: When using workspaces, you need to know which one you're in
  local workspace = window:active_workspace()
  local ws_name = workspace:match("([^/]+)$") or workspace  -- Extract basename
  table.insert(cells, { Foreground = { Color = "#89b4fa" } })  -- Blue
  table.insert(cells, { Text = "  " .. ws_name })

  -- CURRENT WORKING DIRECTORY
  -- WHY: Quick reference without running pwd
  local cwd = pane:get_current_working_dir()
  if cwd then
    local home = os.getenv("HOME") or ""
    local path = cwd.file_path:gsub(home, "~")
    -- Truncate very long paths to keep status bar readable
    if #path > 40 then
      path = "…" .. path:sub(-39)  -- Show last 39 chars with ellipsis
    end
    table.insert(cells, { Foreground = { Color = "#6c7086" } })  -- Overlay0 (gray)
    table.insert(cells, { Text = "  " .. path })
  end

  -- TIME
  -- WHY: Convenient clock without needing to look away from terminal
  table.insert(cells, { Foreground = { Color = "#585b70" } })  -- Surface2 (dark gray)
  table.insert(cells, { Text = "  " .. wezterm.strftime("%H:%M") .. " " })

  -- Apply the formatted status bar
  window:set_right_status(wezterm.format(cells))
end)

-- ============================================================================
-- RETURN THE CONFIGURATION
-- ============================================================================
-- This is required - WezTerm loads this file and uses the returned table
return config
