-- ============================================================================
-- PICKERS MODULE
-- ============================================================================
-- Fuzzy pickers for tabs, directories, themes, etc.

local wezterm = require 'wezterm'
local act = wezterm.action
local theme = require 'theme'
local layouts = require 'layouts'

local M = {}

-- Show the zoxide-powered Quick Open picker
function M.show_quick_open_picker(window, pane)
  local home = os.getenv("HOME") or ""
  local tabs = window:mux_window():tabs()

  local green = theme.colors.green
  local yellow = theme.colors.yellow
  local aqua = theme.colors.cyan
  local gray = theme.colors.fg_dim
  local orange = theme.colors.orange

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
  local success, stdout, stderr = wezterm.run_child_process({ '/opt/homebrew/bin/zoxide', 'query', '-l' })
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

  window:perform_action(
    act.InputSelector({
      title = wezterm.format({
        { Foreground = { Color = theme.colors.cyan } },
        { Attribute = { Intensity = "Bold" } },
        { Text = "󰍉  Quick Open" },
      }),
      description = wezterm.format({
        { Foreground = { Color = green } },
        { Text = "●" },
        { Foreground = { Color = gray } },
        { Text = " switch  " },
        { Foreground = { Color = yellow } },
        { Text = "○" },
        { Foreground = { Color = gray } },
        { Text = " open  " },
        { Foreground = { Color = orange } },
        { Text = "+" },
        { Foreground = { Color = gray } },
        { Text = " create new" },
      }),
      fuzzy_description = wezterm.format({
        { Foreground = { Color = theme.colors.pink } },
        { Attribute = { Intensity = "Bold" } },
        { Text = "󰈞 Search: " },
      }),
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
        if id == nil and label == nil then return end

        if id then
          local existing = open_dirs[id:lower()]
          if existing then
            existing.tab:activate()
          else
            inner_window:mux_window():spawn_tab({ cwd = id })
          end
          return
        end

        local user_input = label
        if not user_input or user_input == "" then return end

        local target_path
        if user_input:match("^/") then
          target_path = user_input
        elseif user_input:match("^~") then
          target_path = user_input:gsub("^~", home)
        else
          target_path = home .. "/dev/" .. user_input
        end

        local check_success, _, _ = wezterm.run_child_process({ 'test', '-d', target_path })
        if not check_success then
          local mkdir_success, _, mkdir_err = wezterm.run_child_process({ 'mkdir', '-p', target_path })
          if not mkdir_success then
            wezterm.log_error("Failed to create directory: " .. tostring(mkdir_err))
            inner_window:toast_notification('WezTerm', 'Failed to create: ' .. target_path, nil, 3000)
            return
          end
          inner_window:toast_notification('WezTerm', 'Created: ' .. target_path:gsub(home, "~"), nil, 2000)
        end

        inner_window:mux_window():spawn_tab({ cwd = target_path })
      end),
    }),
    pane
  )
end

return M
