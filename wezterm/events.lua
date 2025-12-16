-- ============================================================================
-- EVENTS MODULE
-- ============================================================================
-- Event handlers for tab titles, window titles, status bar, etc.

local wezterm = require 'wezterm'
local helpers = require 'helpers'
local theme = require 'theme'
local layouts = require 'layouts'

local M = {}

function M.setup()
  -- Initialize global state
  wezterm.GLOBAL.user_selected_theme = wezterm.GLOBAL.user_selected_theme or nil
  wezterm.GLOBAL.claude_alerts = wezterm.GLOBAL.claude_alerts or {}

  -- CUSTOM TAB TITLES
  wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
    local pane = tab.active_pane
    local cwd = pane.current_working_dir

    local dir_name = "~"
    if cwd and cwd.file_path then
      dir_name = cwd.file_path:match("([^/]+)$") or "~"
    end

    -- Check for Claude alert on this tab (use string key for GLOBAL table)
    local tab_id_str = tostring(tab.tab_id)
    local alert = wezterm.GLOBAL.claude_alerts[tab_id_str]
    local indicator = ""
    local alert_bg = nil

    if alert and not tab.is_active then
      local elapsed = os.time() - alert.time
      if elapsed < 60 then  -- Show alert for 60 seconds
        -- Pulse effect: alternate icons based on time
        local pulse = math.floor(elapsed * 2) % 2 == 0
        if alert.type == 'stop' then
          indicator = pulse and "🔴 " or "⭕ "
          alert_bg = pulse and "#662222" or "#442222"
        else  -- notification
          indicator = pulse and "🔔 " or "🔕 "
          alert_bg = pulse and "#664422" or "#443311"
        end
      else
        -- Alert expired, clear it
        wezterm.GLOBAL.claude_alerts[tab_id_str] = nil
      end
    end

    -- Fallback to unseen output indicator if no Claude alert
    if indicator == "" then
      for _, p in ipairs(tab.panes) do
        if p.has_unseen_output then
          indicator = "● "
          break
        end
      end
    end

    local zoom = ""
    if tab.active_pane.is_zoomed then
      zoom = "🔍 "
    end

    local title = string.format(" %s%s%s ", indicator, zoom, dir_name)

    if tab.is_active then
      -- Clear alert when tab becomes active
      wezterm.GLOBAL.claude_alerts[tab_id_str] = nil
      return {
        { Background = { Color = theme.colors.bg_selection } },
        { Foreground = { Color = theme.colors.fg_bright } },
        { Text = title },
      }
    end

    -- Use alert background if present, otherwise default
    local bg_color = alert_bg or theme.colors.bg
    return {
      { Background = { Color = bg_color } },
      { Foreground = { Color = theme.colors.fg_dim } },
      { Text = title },
    }
  end)

  -- WINDOW TITLE
  wezterm.on('format-window-title', function(tab, pane, tabs, panes, cfg)
    return helpers.short_cwd(pane)
  end)

  -- STATUS BAR
  wezterm.on("update-status", function(window, pane)
    -- Track directory focus time
    local cwd = pane:get_current_working_dir()
    if cwd and cwd.file_path then
      layouts.record_dir_focus(cwd.file_path)
    end

    -- Dynamic color scheme based on cwd (MERGE into existing overrides, don't replace!)
    if not wezterm.GLOBAL.user_selected_theme then
      local scheme = helpers.scheme_for_cwd(pane)
      local overrides = window:get_config_overrides() or {}

      if scheme and scheme ~= overrides.color_scheme then
        overrides.color_scheme = scheme
        window:set_config_overrides(overrides)
      elseif not scheme and overrides.color_scheme then
        overrides.color_scheme = nil
        window:set_config_overrides(overrides)
      end
    end

    -- Disable left status bar
    window:set_left_status("")

    -- Build right status bar
    local cells = {}

    -- Mode indicator
    local mode = window:active_key_table()
    if mode then
      table.insert(cells, { Foreground = { Color = theme.colors.pink } })
      table.insert(cells, { Attribute = { Intensity = "Bold" } })
      table.insert(cells, { Text = " " .. mode:upper() .. " │" })
      table.insert(cells, { Attribute = { Intensity = "Normal" } })
    end

    -- Leader key indicator
    if window:leader_is_active() then
      table.insert(cells, { Foreground = { Color = theme.colors.orange } })
      table.insert(cells, { Attribute = { Intensity = "Bold" } })
      table.insert(cells, { Text = " LEADER │" })
      table.insert(cells, { Attribute = { Intensity = "Normal" } })
    end

    -- Current working directory
    local cwd = pane:get_current_working_dir()
    if cwd then
      local home = os.getenv("HOME") or ""
      local path = cwd.file_path:gsub(home, "~")
      if #path > 40 then
        path = "…" .. path:sub(-39)
      end
      table.insert(cells, { Foreground = { Color = theme.colors.fg_dim } })
      table.insert(cells, { Text = "  " .. path })
    end

    window:set_right_status(wezterm.format(cells))
  end)

  -- SLID PRESENTATION MODE
  wezterm.on('user-var-changed', function(window, pane, name, value)
    if name == 'slid_presentation' then
      local overrides = window:get_config_overrides() or {}
      if value == '1' then
        overrides.enable_tab_bar = false
        overrides.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
      else
        overrides.enable_tab_bar = nil
        overrides.window_padding = nil
      end
      window:set_config_overrides(overrides)
    end

    -- CLAUDE ALERT HANDLER
    if name == 'claude_alert' then
      local tab = pane:tab()
      if tab then
        local tab_id = tostring(tab:tab_id())
        wezterm.GLOBAL.claude_alerts[tab_id] = {
          time = os.time(),
          type = value,  -- 'stop' or 'notification'
        }
        wezterm.log_info('Claude alert received: ' .. value .. ' for tab ' .. tab_id)
      end
    end

    -- CLAUDE PANE STATE HANDLER - Changes background when Claude is waiting
    if name == 'claude_pane_state' then
      wezterm.log_info('Claude pane state received: ' .. tostring(value))
      local overrides = window:get_config_overrides() or {}

      if value == 'waiting' then
        -- Apply a tinted color scheme or custom colors for waiting state
        overrides.colors = overrides.colors or {}
        overrides.colors.background = '#1a0808'  -- Dark red tint
        wezterm.log_info('Setting waiting background: #1a0808')
      else
        -- Reset to default (remove custom background)
        if overrides.colors then
          overrides.colors.background = nil
          if next(overrides.colors) == nil then
            overrides.colors = nil
          end
        end
        wezterm.log_info('Resetting to default background')
      end

      window:set_config_overrides(overrides)
    end
  end)

  -- BELL HANDLER - Also triggers tab alert
  wezterm.on('bell', function(window, pane)
    local tab = pane:tab()
    if tab then
      local tab_id = tostring(tab:tab_id())
      local active_tab = window:active_tab()
      local is_active = active_tab and tostring(active_tab:tab_id()) == tab_id

      if not is_active then
        -- Only set alert if not already set (don't override claude_alert with bell)
        if not wezterm.GLOBAL.claude_alerts[tab_id] then
          wezterm.GLOBAL.claude_alerts[tab_id] = {
            time = os.time(),
            type = 'bell',
          }
        end
      end
    end
  end)
end

return M
