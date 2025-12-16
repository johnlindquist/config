-- ============================================================================
-- PICKERS MODULE
-- ============================================================================
-- Fuzzy pickers for tabs, directories, themes, etc.

local wezterm = require 'wezterm'
local act = wezterm.action
local theme = require 'theme'
local layouts = require 'layouts'
local helpers = require 'helpers'

local M = {}

-- Keyboard shortcuts data (updated to reflect actual bindings)
local shortcuts = {
  -- Navigation
  { key = "⌘P/N", desc = "Quick Open picker", cat = "nav" },
  { key = "⌘⇧P", desc = "Open in Cursor editor", cat = "nav" },
  { key = "⌘O", desc = "Workspace switcher (zoxide)", cat = "nav" },
  { key = "⌘T", desc = "New tab (pick dir first)", cat = "nav" },
  { key = "⌘W", desc = "Smart close (context-aware)", cat = "nav" },
  { key = "⌘1-9", desc = "Jump to pane by number", cat = "nav" },
  { key = "⌘F", desc = "Search in scrollback", cat = "nav" },
  -- Panes
  { key = "⌘D", desc = "Smart split (layout-aware)", cat = "pane" },
  { key = "⌘⇧D", desc = "Split pane down", cat = "pane" },
  { key = "⌘E", desc = "Pane selector (number overlay)", cat = "pane" },
  { key = "⌘⇧E", desc = "Swap panes", cat = "pane" },
  { key = "⌥hjkl", desc = "Navigate panes (vim-style)", cat = "pane" },
  { key = "⌥⇧hjkl", desc = "Resize panes", cat = "pane" },
  { key = "⌥f", desc = "Toggle pane zoom", cat = "pane" },
  { key = "⌥n", desc = "New pane (auto-layout)", cat = "pane" },
  { key = "⌥x", desc = "Close pane (no confirm)", cat = "pane" },
  -- Layouts
  { key = "⌘⇧L", desc = "Layout template picker", cat = "layout" },
  { key = "⌥Space", desc = "Layout mode picker", cat = "layout" },
  { key = "⌥[]", desc = "Cycle layout modes (toast)", cat = "layout" },
  { key = "⌥r", desc = "Rotate panes", cat = "layout" },
  { key = "⌥=", desc = "Reset zoom", cat = "layout" },
  -- Power
  { key = "⌘/", desc = "Show this shortcuts help", cat = "power" },
  { key = "⌘⇧T", desc = "Theme picker", cat = "power" },
  { key = "⌘K", desc = "Command palette", cat = "power" },
  { key = "⌘⇧K", desc = "Clear scrollback", cat = "power" },
  { key = "⌘⇧F", desc = "Toggle fullscreen", cat = "power" },
  { key = "⌘⇧N", desc = "New window", cat = "power" },
  { key = "trigger", desc = "App launcher (via trigger)", cat = "power" },
  -- Leader (Ctrl+B)
  { key = "^B z", desc = "Zen mode (hide tabs)", cat = "leader" },
  { key = "^B s", desc = "Save session (resurrect)", cat = "leader" },
  { key = "^B t", desc = "Cycle themes", cat = "leader" },
  { key = "^B ⇧T", desc = "Restore auto-theme", cat = "leader" },
  { key = "^B ,", desc = "Rename tab", cat = "leader" },
  { key = "^B r", desc = "Enter resize mode", cat = "leader" },
  { key = "^B [", desc = "Enter copy mode (vim)", cat = "leader" },
  { key = "^B -", desc = "Split vertical", cat = "leader" },
  { key = "^B |", desc = "Split horizontal", cat = "leader" },
  { key = "^B c", desc = "New tab", cat = "leader" },
  { key = "^B n/p", desc = "Next/prev tab", cat = "leader" },
}


-- Show keyboard shortcuts help picker (standalone)
function M.show_shortcuts_picker(window, pane)
  local c = theme.colors
  local choices = {}

  local cat_colors = {
    nav = c.cyan,
    pane = c.green,
    layout = c.orange,
    power = c.pink,
    leader = c.purple,
  }
  local cat_names = {
    nav = "NAV",
    pane = "PANE",
    layout = "LAYOUT",
    power = "POWER",
    leader = "LEADER",
  }

  for _, s in ipairs(shortcuts) do
    local label = wezterm.format({
      { Foreground = { Color = c.yellow } },
      { Attribute = { Intensity = "Bold" } },
      { Text = string.format("%-10s", s.key) },
      { Attribute = { Intensity = "Normal" } },
      { Foreground = { Color = c.fg } },
      { Text = " " .. s.desc .. "  " },
      { Foreground = { Color = cat_colors[s.cat] or c.fg_dim } },
      { Text = "[" .. (cat_names[s.cat] or s.cat) .. "]" },
    })
    table.insert(choices, { id = "shortcut:" .. s.key, label = label })
  end

  window:perform_action(
    act.InputSelector({
      title = wezterm.format({
        { Foreground = { Color = c.cyan } },
        { Attribute = { Intensity = "Bold" } },
        { Text = "  Keyboard Shortcuts" },
      }),
      choices = choices,
      fuzzy = true,
      fuzzy_description = wezterm.format({
        { Foreground = { Color = c.pink } },
        { Text = "󰈞 Filter: " },
      }),
      action = wezterm.action_callback(function(_, _, _, _)
        -- Selecting a shortcut just dismisses the picker
      end),
    }),
    pane
  )
end

-- Show the zoxide-powered Quick Open picker
-- action_mode: 'tab' (default) opens in new tab, 'cursor' opens in Cursor editor
function M.show_quick_open_picker(window, pane, action_mode)
  local home = os.getenv("HOME") or ""
  local tabs = window:mux_window():tabs()

  local green = theme.colors.green
  local yellow = theme.colors.yellow
  local aqua = theme.colors.cyan

  -- Build a map of directories that have open tabs
  local open_dirs = {}
  for _, t in ipairs(tabs) do
    for _, p in ipairs(t:panes()) do
      local cwd = p:get_current_working_dir()
      if cwd and cwd.file_path then
        local normalized = cwd.file_path:lower()
        open_dirs[normalized] = { tab = t, tab_id = t:tab_id(), original_path = cwd.file_path }
      end
    end
  end

  -- Get zoxide directories
  local success, stdout, stderr = wezterm.run_child_process({ helpers.zoxide_path, 'query', '-l' })
  if not success then
    wezterm.log_error("zoxide failed: " .. tostring(stderr))
    return
  end

  local open_choices = {}
  local unopened_choices = {}
  local seen_normalized = {}

  for line in stdout:gmatch('[^\n]+') do
    local normalized = line:lower()
    if seen_normalized[normalized] then
      goto continue
    end
    seen_normalized[normalized] = true

    local open_entry = open_dirs[normalized]
    local is_open = open_entry ~= nil

    local actual_path = is_open and open_entry.original_path or line
    local display = actual_path:gsub("^" .. home, "~")

    local label = wezterm.format({
      { Foreground = { Color = is_open and green or yellow } },
      { Text = is_open and "● " or "○ " },
      { Foreground = { Color = aqua } },
      { Text = display },
    })

    if is_open then
      table.insert(open_choices, { id = actual_path, label = label, focus_time = layouts.get_dir_focus_time(normalized) })
    else
      table.insert(unopened_choices, { id = line, label = label })
    end
    ::continue::
  end

  -- Sort open tabs by most recently focused
  table.sort(open_choices, function(a, b)
    return a.focus_time > b.focus_time
  end)

  -- Combine: open tabs first, then unopened directories
  local choices = {}
  for _, choice in ipairs(open_choices) do
    table.insert(choices, { id = choice.id, label = choice.label })
  end
  for _, choice in ipairs(unopened_choices) do
    table.insert(choices, choice)
  end

  -- Ensure ~/dev is always first in the list
  local dev_path = home .. "/dev"
  local dev_normalized = dev_path:lower()
  local dev_index = nil
  for i, choice in ipairs(choices) do
    if choice.id:lower() == dev_normalized then
      dev_index = i
      break
    end
  end

  if dev_index then
    -- Move ~/dev to front
    local dev_choice = table.remove(choices, dev_index)
    table.insert(choices, 1, dev_choice)
  else
    -- ~/dev not in list, add it at the front
    local is_open = open_dirs[dev_normalized] ~= nil
    local label = wezterm.format({
      { Foreground = { Color = is_open and green or yellow } },
      { Text = is_open and "● " or "○ " },
      { Foreground = { Color = aqua } },
      { Text = "~/dev" },
    })
    table.insert(choices, 1, { id = dev_path, label = label })
  end

  -- Determine title and hint based on mode
  action_mode = action_mode or 'tab'
  local is_cursor_mode = action_mode == 'cursor'

  local title = wezterm.format({
    { Foreground = { Color = is_cursor_mode and theme.colors.purple or theme.colors.cyan } },
    { Attribute = { Intensity = "Bold" } },
    { Text = is_cursor_mode and "  Open in Cursor" or "󰍉  Quick Open" },
  })

  local hint = is_cursor_mode and "(opens in Cursor)" or "(⌘⇧P for Cursor)"

  window:perform_action(
    act.InputSelector({
      title = title,
      fuzzy_description = wezterm.format({
        { Foreground = { Color = theme.colors.pink } },
        { Attribute = { Intensity = "Bold" } },
        { Text = "󰈞 Search: " },
        { Attribute = { Intensity = "Normal" } },
        { Foreground = { Color = theme.colors.fg_dim } },
        { Text = hint },
      }),
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
        if id == nil and label == nil then return end

        -- Resolve target path from id or user input
        local target_path
        if id then
          target_path = id
        else
          local user_input = label
          if not user_input or user_input == "" then return end

          if user_input:match("^/") then
            target_path = user_input
          elseif user_input:match("^~") then
            target_path = user_input:gsub("^~", home)
          else
            target_path = home .. "/dev/" .. user_input
          end

          -- Create directory if it doesn't exist
          local check_success, _, _ = wezterm.run_child_process({ 'test', '-d', target_path })
          if not check_success then
            local mkdir_success, _, mkdir_err = wezterm.run_child_process({ 'mkdir', '-p', target_path })
            if not mkdir_success then
              wezterm.log_error("Failed to create directory: " .. tostring(mkdir_err))
              return
            end
          end
        end

        -- Execute action based on mode
        if is_cursor_mode then
          -- Open in Cursor editor
          wezterm.background_child_process({ '/usr/local/bin/cursor', target_path })
        else
          -- Default: open/switch tab
          local existing = open_dirs[target_path:lower()]
          if existing then
            existing.tab:activate()
          else
            inner_window:mux_window():spawn_tab({ cwd = target_path })
          end
        end
      end),
    }),
    pane
  )
end

-- Show copy_path picker (hierarchical directory browser, copies path to clipboard)
function M.show_copy_path_picker(window, pane, start_path)
  local current_path = start_path or os.getenv('HOME')

  local function show_dir(dir_path)
    -- Get directory contents
    local success, stdout = wezterm.run_child_process({
      'ls', '-1a', dir_path
    })

    if not success then
      wezterm.log_error("Failed to list directory: " .. dir_path)
      return
    end

    local entries = {}
    for entry in stdout:gmatch('[^\n]+') do
      if entry ~= '.' then
        table.insert(entries, entry)
      end
    end

    -- Sort: directories first (with /), then files
    table.sort(entries, function(a, b)
      local a_is_parent = a == '..'
      local b_is_parent = b == '..'
      if a_is_parent then return true end
      if b_is_parent then return false end
      return a:lower() < b:lower()
    end)

    -- Build choices
    local choices = {}
    local home = os.getenv('HOME')
    local display_path = dir_path:gsub('^' .. home, '~')

    -- Add "copy this directory" option at top
    table.insert(choices, {
      id = 'COPY:' .. dir_path,
      label = wezterm.format({
        { Foreground = { Color = theme.colors.green } },
        { Attribute = { Intensity = 'Bold' } },
        { Text = '  [Copy this path: ' .. display_path .. ']' },
      })
    })

    for _, entry in ipairs(entries) do
      local full_path = dir_path .. '/' .. entry
      if entry == '..' then
        full_path = dir_path:match('(.+)/[^/]+$') or '/'
      end

      -- Check if directory
      local is_dir = false
      local check_success, _ = wezterm.run_child_process({ 'test', '-d', full_path })
      is_dir = check_success

      local icon = is_dir and ' ' or ' '
      local color = is_dir and theme.colors.cyan or theme.colors.fg

      if entry == '..' then
        icon = '󰁞 '
        color = theme.colors.yellow
      end

      local label = wezterm.format({
        { Foreground = { Color = color } },
        { Text = icon .. entry },
      })

      table.insert(choices, {
        id = (is_dir and 'DIR:' or 'FILE:') .. full_path,
        label = label
      })
    end

    window:perform_action(
      act.InputSelector({
        title = wezterm.format({
          { Foreground = { Color = theme.colors.purple } },
          { Attribute = { Intensity = 'Bold' } },
          { Text = '  ' .. display_path },
        }),
        fuzzy_description = wezterm.format({
          { Foreground = { Color = theme.colors.pink } },
          { Text = '󰈞 Filter: ' },
          { Foreground = { Color = theme.colors.fg_dim } },
          { Text = '(Enter on file to copy path)' },
        }),
        choices = choices,
        fuzzy = true,
        action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
          if not id then return end

          local action_type, path = id:match('^(%u+):(.+)$')

          if action_type == 'DIR' then
            -- Navigate into directory
            show_dir(path)
          elseif action_type == 'FILE' or action_type == 'COPY' then
            -- Copy path to clipboard
            inner_window:copy_to_clipboard(path)
            wezterm.log_info('Copied to clipboard: ' .. path)
          end
        end),
      }),
      pane
    )
  end

  show_dir(current_path)
end

-- Show app launcher picker (lists all installed macOS apps)
function M.show_app_launcher(window, pane)
  -- Get list of apps from /Applications and ~/Applications
  local apps = {}
  local seen = {}

  local function scan_dir(dir)
    local success, stdout = wezterm.run_child_process({
      'find', dir, '-maxdepth', '2', '-name', '*.app', '-type', 'd'
    })
    if success and stdout then
      for app_path in stdout:gmatch('[^\n]+') do
        local app_name = app_path:match('([^/]+)%.app$')
        if app_name and not seen[app_name:lower()] then
          seen[app_name:lower()] = true
          table.insert(apps, { name = app_name, path = app_path })
        end
      end
    end
  end

  scan_dir('/Applications')
  scan_dir('/System/Applications')
  scan_dir(os.getenv('HOME') .. '/Applications')

  -- Sort alphabetically
  table.sort(apps, function(a, b) return a.name:lower() < b.name:lower() end)

  -- Build choices
  local choices = {}
  for _, app in ipairs(apps) do
    local label = wezterm.format({
      { Foreground = { Color = theme.colors.cyan } },
      { Text = " " },
      { Foreground = { Color = theme.colors.fg } },
      { Text = app.name },
    })
    table.insert(choices, { id = app.path, label = label })
  end

  window:perform_action(
    act.InputSelector({
      title = wezterm.format({
        { Foreground = { Color = theme.colors.green } },
        { Attribute = { Intensity = "Bold" } },
        { Text = "  App Launcher" },
      }),
      fuzzy_description = wezterm.format({
        { Foreground = { Color = theme.colors.pink } },
        { Attribute = { Intensity = "Bold" } },
        { Text = "󰈞 Search: " },
      }),
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
        if id then
          wezterm.background_child_process({ 'open', '-a', id })
        end
      end),
    }),
    pane
  )
end

return M
