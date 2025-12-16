-- ============================================================================
-- LAYOUTS MODULE
-- ============================================================================
-- Zellij-style auto-layout system and static layout templates

local wezterm = require 'wezterm'
local helpers = require 'helpers'

local M = {}

-- ============================================================================
-- LAYOUT MODE DEFINITIONS
-- ============================================================================
local DEFAULT_LAYOUT_MODE = 'tiled'

-- Tunable: ratio threshold for smart split direction in 'tiled' mode
-- If (cols / rows) > this ratio, split right; otherwise split bottom
-- Adjust this value to match your font/terminal dimensions
M.SMART_SPLIT_RATIO = 2.0

M.LAYOUT_MODES = {
  { id = 'tiled',           name = 'Tiled',           desc = 'Grid layout (Zellij default)' },
  { id = 'vertical',        name = 'Vertical',        desc = 'All panes stacked vertically' },
  { id = 'horizontal',      name = 'Horizontal',      desc = 'All panes side by side' },
  { id = 'main-vertical',   name = 'Main+Vertical',   desc = 'Main left, stack right' },
  { id = 'main-horizontal', name = 'Main+Horizontal', desc = 'Main top, stack bottom' },
}

-- ============================================================================
-- LAYOUT MODE STATE MANAGEMENT
-- ============================================================================
function M.get_layout_mode(tab)
  wezterm.GLOBAL.layout_modes = wezterm.GLOBAL.layout_modes or {}
  return wezterm.GLOBAL.layout_modes[tostring(tab:tab_id())] or DEFAULT_LAYOUT_MODE
end

function M.set_layout_mode(tab, mode)
  wezterm.GLOBAL.layout_modes = wezterm.GLOBAL.layout_modes or {}
  wezterm.GLOBAL.layout_modes[tostring(tab:tab_id())] = mode
end

function M.cycle_layout_mode(current, direction)
  local current_idx = 1
  for i, mode in ipairs(M.LAYOUT_MODES) do
    if mode.id == current then
      current_idx = i
      break
    end
  end
  local new_idx = current_idx + direction
  if new_idx < 1 then new_idx = #M.LAYOUT_MODES end
  if new_idx > #M.LAYOUT_MODES then new_idx = 1 end
  return M.LAYOUT_MODES[new_idx].id
end

-- ============================================================================
-- DIRECTORY FOCUS HISTORY
-- ============================================================================
function M.record_dir_focus(dir_path)
  if not dir_path then return end
  wezterm.GLOBAL.dir_focus_times = wezterm.GLOBAL.dir_focus_times or {}
  wezterm.GLOBAL.dir_focus_times[dir_path:lower()] = os.time()
end

function M.get_dir_focus_time(dir_path)
  wezterm.GLOBAL.dir_focus_times = wezterm.GLOBAL.dir_focus_times or {}
  return wezterm.GLOBAL.dir_focus_times[dir_path] or 0
end

-- ============================================================================
-- SMART SPLIT HELPERS
-- ============================================================================
local function get_split_size(mode, pane_count)
  if mode == 'main-vertical' or mode == 'main-horizontal' then
    return (pane_count == 1) and helpers.pct(40) or helpers.pct(50)
  end
  return helpers.pct(50)
end

local function pick_stack_pane(tab, mode)
  local info = tab:panes_with_info()
  if #info == 0 then
    return tab:active_pane()
  end

  local best = info[1]
  if mode == 'main-vertical' then
    for _, p in ipairs(info) do
      if (p.left > best.left) or (p.left == best.left and p.top > best.top) then
        best = p
      end
    end
  else
    for _, p in ipairs(info) do
      if (p.top > best.top) or (p.top == best.top and p.left > best.left) then
        best = p
      end
    end
  end
  return best.pane
end

local function get_smart_split_direction(pane, mode, pane_count)
  local dims = pane:get_dimensions()
  local cols = dims.cols
  local rows = dims.viewport_rows

  if mode == 'vertical' then
    return 'Bottom'
  elseif mode == 'horizontal' then
    return 'Right'
  elseif mode == 'main-vertical' then
    return pane_count == 1 and 'Right' or 'Bottom'
  elseif mode == 'main-horizontal' then
    return pane_count == 1 and 'Bottom' or 'Right'
  else
    -- Tiled mode: use tunable ratio (cols/rows vs threshold)
    local ratio = cols / rows
    return (ratio > M.SMART_SPLIT_RATIO) and 'Right' or 'Bottom'
  end
end

-- ============================================================================
-- SMART NEW PANE
-- ============================================================================
function M.smart_new_pane(window, pane)
  local tab = window:active_tab()
  if not tab then return end

  local mode = M.get_layout_mode(tab)
  local pane_count = #tab:panes()
  local cwd = helpers.cwd_path(pane:get_current_working_dir())

  local target = pane
  if (mode == 'main-vertical' or mode == 'main-horizontal') and pane_count > 1 then
    target = pick_stack_pane(tab, mode)
  end

  local direction = get_smart_split_direction(target, mode, pane_count)
  local size = get_split_size(mode, pane_count)

  local split_args = { direction = direction, size = size }
  if cwd then
    split_args.cwd = cwd
  end

  local success, result = pcall(function()
    return target:split(split_args)
  end)

  if success and result then
    result:activate()
  end
end

-- ============================================================================
-- STATIC LAYOUT TEMPLATES
-- ============================================================================
M.templates = {}

-- Dev layout: Editor + terminal stack (60/40)
function M.templates.dev(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  local right = main:split({ direction = 'Right', size = helpers.pct(40), cwd = cwd })
  right:split({ direction = 'Bottom', size = helpers.pct(50), cwd = cwd })
  M.set_layout_mode(tab, 'main-vertical')
  tab:set_title('dev')
  return tab
end

-- Editor layout: Full editor + bottom terminal
function M.templates.editor(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  main:split({ direction = 'Bottom', size = helpers.pct(25), cwd = cwd })
  M.set_layout_mode(tab, 'main-horizontal')
  tab:set_title('editor')
  return tab
end

-- Three column layout
function M.templates.three_col(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  main:split({ direction = 'Right', size = helpers.pct(66), cwd = cwd })
  tab:active_pane():split({ direction = 'Right', size = helpers.pct(50), cwd = cwd })
  M.set_layout_mode(tab, 'horizontal')
  tab:set_title('3col')
  return tab
end

-- Monitor layout: htop + logs
function M.templates.monitor(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  main:send_text('htop\n')
  local logs = main:split({ direction = 'Bottom', size = helpers.pct(40), cwd = cwd })
  logs:send_text('# tail -f your logs here\n')
  M.set_layout_mode(tab, 'vertical')
  tab:set_title('monitor')
  return tab
end

-- Quad layout: Four equal panes
function M.templates.quad(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  local right = main:split({ direction = 'Right', size = helpers.pct(50), cwd = cwd })
  main:split({ direction = 'Bottom', size = helpers.pct(50), cwd = cwd })
  right:split({ direction = 'Bottom', size = helpers.pct(50), cwd = cwd })
  M.set_layout_mode(tab, 'tiled')
  tab:set_title('quad')
  return tab
end

-- Stacked layout: Three horizontal rows
function M.templates.stacked(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  main:split({ direction = 'Bottom', size = helpers.pct(66), cwd = cwd })
  tab:active_pane():split({ direction = 'Bottom', size = helpers.pct(50), cwd = cwd })
  M.set_layout_mode(tab, 'vertical')
  tab:set_title('stacked')
  return tab
end

-- Side by side layout: Two columns
function M.templates.side_by_side(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  main:split({ direction = 'Right', size = helpers.pct(50), cwd = cwd })
  M.set_layout_mode(tab, 'horizontal')
  tab:set_title('split')
  return tab
end

-- Focus layout: Main pane + small sidebar
function M.templates.focus(window, cwd)
  local tab = window:mux_window():spawn_tab({ cwd = cwd })
  local main = tab:active_pane()
  main:split({ direction = 'Right', size = helpers.pct(25), cwd = cwd })
  M.set_layout_mode(tab, 'main-vertical')
  tab:set_title('focus')
  return tab
end

-- Layout metadata for pickers
M.layout_list = {
  { id = 'dev',          name = 'Dev',          desc = 'Editor + terminal stack (60/40)' },
  { id = 'editor',       name = 'Editor',       desc = 'Full editor + bottom terminal' },
  { id = 'three_col',    name = '3 Column',     desc = 'Three equal columns' },
  { id = 'quad',         name = 'Quad',         desc = 'Four equal panes' },
  { id = 'stacked',      name = 'Stacked',      desc = 'Three horizontal rows' },
  { id = 'side_by_side', name = 'Side by Side', desc = 'Two vertical columns' },
  { id = 'focus',        name = 'Focus',        desc = 'Main pane + small sidebar' },
  { id = 'monitor',      name = 'Monitor',      desc = 'htop + logs' },
}

-- Apply a layout by name
function M.apply_layout(window, layout_name)
  local pane = window:active_pane()
  local cwd = pane:get_current_working_dir()
  local cwd_path = cwd and cwd.file_path or nil

  if M.templates[layout_name] then
    M.templates[layout_name](window, cwd_path)
    wezterm.log_info('Applied layout: ' .. layout_name)
  else
    wezterm.log_error('Unknown layout: ' .. layout_name)
  end
end

-- ============================================================================
-- PROJECT LAYOUTS
-- ============================================================================
M.project_layouts = {}
M.project_layout_functions = {}

function M.get_project_layout(workspace_name)
  for pattern, _ in pairs(M.project_layout_functions) do
    if workspace_name:find(pattern) then
      return { type = 'function', pattern = pattern }
    end
  end
  for _, mapping in ipairs(M.project_layouts) do
    if workspace_name:find(mapping.pattern) then
      return { type = 'layout', layout = mapping.layout }
    end
  end
  return nil
end

function M.apply_project_layout(window, workspace_name, cwd)
  local project = M.get_project_layout(workspace_name)
  if not project then return false end

  if project.type == 'function' then
    M.project_layout_functions[project.pattern](window, cwd)
    return true
  elseif project.type == 'layout' then
    M.templates[project.layout](window, cwd)
    return true
  end
  return false
end

return M
