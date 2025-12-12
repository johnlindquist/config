-- ============================================================================
-- HELPER FUNCTIONS MODULE
-- ============================================================================
-- Utility functions used across the WezTerm configuration

local wezterm = require 'wezterm'

local M = {}

-- Detect if the current pane is running Neovim/Vim
function M.is_vim(pane)
  local process_info = pane:get_foreground_process_info()
  local process_name = process_info and process_info.executable or ""
  return process_name:find("n?vim") ~= nil
end

-- Detect if the current pane is running micro editor
function M.is_micro(pane)
  local process_info = pane:get_foreground_process_info()
  local process_name = process_info and process_info.executable or ""
  return process_name:find("micro") ~= nil
end

-- Detect if running any terminal editor (vim, neovim, micro)
function M.is_editor(pane)
  return M.is_vim(pane) or M.is_micro(pane)
end

-- Percent helper for pane:split size
function M.pct(n)
  return n / 100.0
end

-- Safe cwd extraction (handles both string and Url object formats)
function M.cwd_path(cwd)
  if not cwd then return nil end
  if type(cwd) == "string" then return cwd end
  return cwd.file_path
end

-- Shorten cwd for display (shows last 2 path components)
-- Handles both Pane objects (method call) and PaneInformation tables (property access)
function M.short_cwd(pane)
  local cwd
  local ok, result = pcall(function() return pane:get_current_working_dir() end)
  if ok and result then
    cwd = result
  else
    cwd = pane.current_working_dir
  end
  if not cwd then return "~" end
  local home = os.getenv("HOME") or ""
  local path = cwd.file_path:gsub(home, "~")
  local last_two = path:match("([^/]+/[^/]+)$")
  return last_two or path:match("([^/]+)$") or path
end

-- Map cwd patterns to color schemes
function M.scheme_for_cwd(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd or not cwd.file_path then return nil end
  local home = os.getenv("HOME") or ""
  local path = cwd.file_path:gsub("^file://", ""):gsub(home, "~")

  -- Define your project-to-scheme mappings here
  local mappings = {
    -- { pattern = "~/dev/special-project", scheme = "Catppuccin Mocha" },
  }

  for _, m in ipairs(mappings) do
    if path:find(m.pattern, 1, true) then
      return m.scheme
    end
  end
  return nil
end

return M
