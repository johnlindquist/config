# WezTerm Power User Guide

A guide to WezTerm workspaces, pane management, and productivity tricks for users coming from iTerm2.

## Modular Config Structure

The config is split into logical modules for maintainability:

```
~/.config/wezterm/
├── wezterm.lua          # Main entry point (imports modules)
├── helpers.lua          # Utility functions (is_vim, is_micro, cwd helpers)
├── theme.lua            # Color definitions and theme list
├── layouts.lua          # Zellij-style layouts and smart pane management
├── appearance.lua       # Visual config (fonts, colors, window settings)
├── pickers.lua          # Fuzzy pickers (Quick Open, themes)
├── events.lua           # Event handlers (tab titles, status bar)
├── keys/
│   ├── init.lua         # Key aggregator
│   ├── micro.lua        # Micro editor Cmd→Ctrl mappings
│   ├── navigation.lua   # Pane/tab/workspace navigation
│   ├── layouts.lua      # Layout and splitting keybindings
│   └── power.lua        # Themes, zen mode, session management
└── wezterm.lua.backup   # Original monolithic config (for reference)
```

**Key modules:**
- `helpers.lua` - `is_vim()`, `is_micro()`, `short_cwd()`, `scheme_for_cwd()`
- `layouts.lua` - Layout modes (tiled/vertical/horizontal/main-*), smart_new_pane(), layout templates
- `theme.lua` - Hardcore theme colors, high contrast theme list
- `pickers.lua` - `show_quick_open_picker()` for Cmd+P/Cmd+N

## Quick Reference

| Key | Action |
|-----|--------|
| `Cmd+D` | Smart split (uses current layout mode) |
| `Cmd+Shift+D` | Split pane down |
| `Cmd+W` | Close current pane (closes tab if last pane) |
| `Cmd+T` | New tab with zoxide picker |
| `Cmd+N` | Quick Open picker (zoxide dirs, switch/create) |
| `Cmd+P` | Quick Open picker (same as Cmd+N) |
| `Cmd+Shift+S` | Fuzzy workspace picker |
| `Cmd+O` | Smart workspace switcher (zoxide) |
| `Cmd+E` | Pane selector (number overlay) |
| `Cmd+Shift+E` | Swap panes |
| `Cmd+K` | Command palette |
| `Cmd+L` | Launcher |
| `Cmd+Shift+T` | Theme picker |
| `Cmd+Shift+L` | Layout template picker |
| `Cmd+Shift+F` | Toggle fullscreen |
| `Cmd+1-9` | Switch to pane by number |
| `Ctrl+B` + `z` | Toggle pane zoom / Zen mode |
| `Ctrl+B` + `h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl+B` + `t` | Cycle themes |
| `Ctrl+B` + `s` | Save workspace (resurrect) |
| `Alt+n` | Smart new pane (Zellij-style) |
| `Alt+[/]` | Cycle layout modes |
| `Alt+Space` | Layout mode picker |
| `Alt+h/j/k/l` | Navigate panes (Zellij-style) |
| `Alt+Shift+h/j/k/l` | Resize panes |
| `Alt+f` | Toggle pane zoom |
| `Alt+x` | Close pane (no confirm) |

## Zellij-Style Layout System

The config includes a Zellij-inspired auto-layout system in `layouts.lua`:

### Layout Modes
- **tiled** - Grid layout, splits larger dimension (default)
- **vertical** - All panes stacked top-to-bottom
- **horizontal** - All panes side by side
- **main-vertical** - Main pane left (60%), stack right (40%)
- **main-horizontal** - Main pane top (60%), stack bottom (40%)

### How It Works
1. Each tab has a layout mode stored in `wezterm.GLOBAL.layout_modes`
2. `Alt+n` or `Cmd+D` creates panes using the current mode's logic
3. `Alt+[` and `Alt+]` cycle through modes
4. Status bar shows current mode (when in non-default)

### Static Layout Templates
Access via `Cmd+Shift+L` or `Leader+Shift+<key>`:
- `dev` - Editor + terminal stack (60/40)
- `editor` - Full editor + bottom terminal
- `three_col` - Three equal columns
- `quad` - Four equal panes
- `stacked` - Three horizontal rows
- `side_by_side` - Two vertical columns
- `focus` - Main pane + small sidebar
- `monitor` - htop + logs (auto-starts htop)

## Supported Terminal Editors

WezTerm is configured to work seamlessly with these terminal editors:

### micro
- Cmd+key mappings translate to Ctrl+key when micro is running (in `keys/micro.lua`)
- Cmd+S → save, Cmd+Q → quit, Cmd+Z → undo, Cmd+C/V/X → copy/paste/cut
- The leader key is Ctrl+B to avoid conflicts with micro's Ctrl+Q quit

## Core Concepts

### Tabs vs Panes vs Workspaces

- **Panes**: Splits within a tab. Each pane is its own terminal session.
- **Tabs**: Container for one or more panes. Shown in the tab bar.
- **Workspaces**: Named collections of tabs/panes. Think of them as "projects" or "contexts".

### iTerm-like Workflow

WezTerm's panes work similarly to iTerm's splits:

```lua
-- Cmd+W closes just the focused pane, not the whole tab
{ mods = "CMD", key = "w", action = act.CloseCurrentPane { confirm = false } }
```

Each split (`Cmd+D`) creates a self-contained pane. `Cmd+W` closes only that pane. When it's the last pane in a tab, the tab closes.

## Fuzzy Finders & Switchers

### Tab Picker (`Cmd+P`)

Fuzzy search through all open tabs by name/title:

```lua
{ mods = "CMD", key = "p", action = act.ShowLauncherArgs { flags = "FUZZY|TABS" } }
```

### Workspace Picker (`Cmd+Shift+S`)

Switch between workspaces:

```lua
{ mods = "CMD|SHIFT", key = "s", action = act.ShowLauncherArgs { flags = "FUZZY|WORKSPACES" } }
```

### Smart Workspace Switcher (`Cmd+O`)

Uses [zoxide](https://github.com/ajeetdsouza/zoxide) to fuzzy-find directories and create/switch workspaces:

```lua
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")

{ mods = "CMD", key = "o", action = workspace_switcher.switch_workspace() }
```

**Prerequisites:**
```bash
brew install zoxide
echo 'eval "$(zoxide init zsh)"' >> ~/.zshrc
```

### Pane Selector (`Cmd+E`)

Shows number overlay on each pane for quick switching:

```lua
{ mods = "CMD", key = "e", action = act.PaneSelect { alphabet = "1234567890", mode = "Activate" } }
```

## Workspaces Deep Dive

### What Are Workspaces?

Workspaces let you organize your terminal sessions by project or context. Each workspace maintains its own set of tabs and panes.

### Creating Workspaces

1. **Via Smart Switcher** (`Cmd+O`): Select a directory, and it creates a workspace named after that directory.

2. **Via Launcher** (`Cmd+L`): Create a new workspace from the launcher menu.

3. **Programmatically**:
```lua
wezterm.mux.spawn_window { workspace = "my-project" }
```

### Switching Workspaces

- `Cmd+Shift+S` - Fuzzy picker for existing workspaces
- `Cmd+O` - Smart switcher (creates or switches)

### Workspace Tips

1. **Name workspaces by project**: When using the smart switcher, workspaces are auto-named by directory.

2. **Persist layouts**: Workspaces remember their tab/pane layout during a session.

3. **Default workspace**: Set a default workspace name:
```lua
config.default_workspace = "main"
```

## Leader Key System

The leader key (`Ctrl+B`) enables tmux-style keybindings:

```lua
config.leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 1000 }
```

After pressing `Ctrl+B`, you have 1 second to press the next key:

| Sequence | Action |
|----------|--------|
| `Ctrl+B` → `-` | Split vertical |
| `Ctrl+B` → `\|` | Split horizontal |
| `Ctrl+B` → `h/j/k/l` | Navigate panes |
| `Ctrl+B` → `z` | Toggle pane zoom |
| `Ctrl+B` → `x` | Close pane (with confirm) |
| `Ctrl+B` → `c` | New tab |
| `Ctrl+B` → `n/p` | Next/previous tab |
| `Ctrl+B` → `1-5` | Jump to tab by number |
| `Ctrl+B` → `[` | Enter copy mode |

**Note**: Using `Ctrl+B` as leader means you lose the "back one character" readline shortcut. Use `Ctrl+A` (beginning of line) remains available.

## Plugins

### Installing Plugins

WezTerm plugins are loaded via URL:

```lua
local plugin = wezterm.plugin.require("https://github.com/user/plugin-name.wezterm")
plugin.apply_to_config(config)
```

### Installed Plugins

1. **[smart_workspace_switcher](https://github.com/MLFlexer/smart_workspace_switcher.wezterm)** - Zoxide-powered workspace management (`Cmd+O`)

2. **[resurrect](https://github.com/MLFlexer/resurrect.wezterm)** - Session persistence (`Leader+s` to save)

## Tips & Tricks

### 1. Quick Directory Navigation

With the smart workspace switcher + zoxide, you can:
- `Cmd+O` → type partial directory name → Enter
- Instantly opens a new workspace in that directory

### 2. Pane Zoom for Focus

`Ctrl+B` → `z` temporarily maximizes the current pane. Press again to restore layout.

### 3. Copy Mode (Vim-style)

`Ctrl+B` → `[` enters copy mode:
- `v` to start selection
- `y` to yank
- `q` to exit

### 4. Command Palette

`Cmd+K` opens the command palette - search for any WezTerm action.

### 5. Hot Reloading

WezTerm supports config hot-reloading. Edit any `.lua` file in `~/.config/wezterm/` and changes apply immediately.

### 6. Zen Mode

`Leader+z` toggles Zen mode - hides tab bar and removes padding for distraction-free work.

## Troubleshooting

### Config Not Loading / Wrong Config

WezTerm searches for config files in this order:
1. `--config-file` CLI argument
2. `$WEZTERM_CONFIG_FILE` environment variable
3. `$XDG_CONFIG_HOME/wezterm/wezterm.lua` (recommended: `~/.config/wezterm/wezterm.lua`)
4. `~/.wezterm.lua` (legacy location)

**IMPORTANT**: If you have BOTH `~/.wezterm.lua` AND `~/.config/wezterm/wezterm.lua`, WezTerm may load the wrong one depending on environment variables. The `WEZTERM_CONFIG_FILE` env var takes precedence.

To debug which config is loading:
```bash
# Check for competing config files
ls -la ~/.wezterm.lua ~/.config/wezterm/wezterm.lua

# Check env var
echo $WEZTERM_CONFIG_FILE

# Test config and see keybindings
wezterm show-keys 2>&1 | head -30

# Test config with debug logging
WEZTERM_LOG=config=debug wezterm show-keys 2>&1 | grep -i error
```

**Fix**: Remove or rename `~/.wezterm.lua` if you want to use `~/.config/wezterm/wezterm.lua`:
```bash
mv ~/.wezterm.lua ~/.wezterm.lua.bak
```

### Pane vs PaneInformation Objects

In event handlers like `format-tab-title` and `format-window-title`, the `pane` parameter is a **PaneInformation table**, not a **Pane object**:
- PaneInformation: Use `pane.current_working_dir` (property access)
- Pane object: Use `pane:get_current_working_dir()` (method call)

To handle both:
```lua
local cwd
if pane.get_current_working_dir then
  cwd = pane:get_current_working_dir()  -- Pane object
else
  cwd = pane.current_working_dir        -- PaneInformation table
end
```

### Color Scheme Not Found

Color scheme names changed in upstream iTerm2-Color-Schemes:
- ❌ `'Gruvbox Dark'` (old name with space)
- ✅ `'GruvboxDark'` (new name, no space)

### Debug Overlay

Press `Ctrl+Shift+L` to open the debug overlay - shows Lua errors and provides a REPL.

### Ctrl+A Not Working?

If you set `Ctrl+A` as your leader key, it intercepts the readline "beginning of line" shortcut. Either:
- Change leader to `Ctrl+B` or `Ctrl+Space`
- Add a double-tap binding to send `Ctrl+A` through

### Space Key Jumping to End of Line?

If you have custom ZLE bindings in zsh, check for `bindkey " "` that might be moving the cursor. Use `zle self-insert` for the fallback case.

### Plugins Not Loading?

WezTerm downloads plugins on first use. Check your network connection and the plugin URL.

## Theme System

### Available Themes (High Contrast)
Defined in `theme.lua`, accessible via `Cmd+Shift+T`:
- Hardcore (default) - Maximum contrast
- Solarized Dark Higher Contrast
- Dracula
- Catppuccin Mocha
- GruvboxDark
- Tokyo Night
- Selenized Dark (Gogh)
- Snazzy

### Dynamic Theming
- `scheme_for_cwd()` in `helpers.lua` can map directories to color schemes
- User-selected themes persist in `wezterm.GLOBAL.user_selected_theme`
- The `update-status` event respects user selection over auto-theming

## Quick Open Picker (Cmd+P / Cmd+N)

The custom picker in `pickers.lua`:
- Shows zoxide frecent directories
- `●` green = tab already open (switches to it)
- `○` yellow = no tab (opens new)
- Type a non-matching path to create new directory
- Sorts open tabs by most recently focused

## Common Development Tasks

### Adding a New Keybinding
1. Identify the category: micro, navigation, layouts, or power
2. Edit the appropriate file in `keys/`
3. Add to the `get_keys()` return table
4. Test with `wezterm show-keys | grep YOUR_KEY`

### Adding a New Layout Template
1. Edit `layouts.lua`
2. Add function to `M.templates` table
3. Add metadata to `M.layout_list`
4. Access via `Cmd+Shift+L` picker or add hotkey in `keys/layouts.lua`

### Debugging
```bash
# Validate config loads
wezterm show-keys 2>&1 | head -5

# Check for Lua errors
WEZTERM_LOG=config=debug wezterm show-keys 2>&1 | grep -i error

# Open debug overlay in WezTerm
Ctrl+Shift+L
```

## WezTerm Lua Config Reference

Comprehensive reference for `wezterm.lua` configuration options.

### Window & Display Options

| Option | Type | Description |
|--------|------|-------------|
| `initial_cols` / `initial_rows` | int | Initial window dimensions |
| `window_decorations` | string | `"TITLE"`, `"RESIZE"`, `"NONE"`, `"TITLE|RESIZE"` |
| `window_padding` | table | `{left, right, top, bottom}` in pixels |
| `window_background_opacity` | float | 0.0-1.0, requires compositor |
| `window_background_gradient` | table | `{orientation, colors, ...}` |
| `window_close_confirmation` | string | `"AlwaysPrompt"`, `"NeverPrompt"` |
| `adjust_window_size_when_changing_font_size` | bool | Resize window with font |
| `window_frame` | table | Frame colors, fonts for fancy tab bar |
| `window_content_alignment` | string | Where to place excess pixels |
| `integrated_title_buttons` | table | `{"Hide", "Maximize", "Close"}` |
| `macos_window_background_blur` | int | macOS blur radius |
| `native_macos_fullscreen_mode` | bool | Use native fullscreen |

### Tab Bar Options

| Option | Type | Description |
|--------|------|-------------|
| `enable_tab_bar` | bool | Show/hide tab bar |
| `hide_tab_bar_if_only_one_tab` | bool | Auto-hide with single tab |
| `tab_bar_at_bottom` | bool | Position at bottom |
| `use_fancy_tab_bar` | bool | Native-style vs retro |
| `tab_max_width` | int | Max tab width in cells |
| `show_tab_index_in_tab_bar` | bool | Show tab numbers |
| `show_new_tab_button_in_tab_bar` | bool | Show + button |
| `show_close_tab_button_in_tabs` | bool | Show X on tabs |
| `tab_bar_style` | table | Custom tab edge styling |

### Font Options

| Option | Type | Description |
|--------|------|-------------|
| `font` | Font | `wezterm.font("Name")` or `wezterm.font_with_fallback({...})` |
| `font_size` | float | Point size |
| `line_height` | float | Multiplier (1.0 = normal) |
| `cell_width` | float | Horizontal scaling |
| `font_rules` | table | Conditional font selection |
| `font_dirs` | table | Additional font directories |
| `font_locator` | string | `"ConfigDirsOnly"`, `"FontConfig"`, `"CoreText"` |
| `font_shaper` | string | `"Harfbuzz"`, `"Allsorts"` |
| `harfbuzz_features` | table | `{"calt=0", "liga=0", ...}` |
| `freetype_load_target` | string | `"Normal"`, `"Light"`, `"Mono"`, `"HorizontalLcd"` |
| `freetype_load_flags` | string | `"DEFAULT"`, `"NO_HINTING"`, `"FORCE_AUTOHINT"` |
| `bold_brightens_ansi_colors` | bool/string | `true`, `false`, `"BrightAndBold"`, `"BrightOnly"` |
| `allow_square_glyphs_to_overflow_width` | string | `"Never"`, `"Always"`, `"WhenFollowedBySpace"` |

### Color Options

| Option | Type | Description |
|--------|------|-------------|
| `color_scheme` | string | Scheme name from built-in or custom |
| `color_scheme_dirs` | table | Additional scheme directories |
| `colors` | table | Individual color overrides |
| `colors.foreground` / `background` | string | Hex colors `"#rrggbb"` |
| `colors.cursor_bg` / `cursor_fg` / `cursor_border` | string | Cursor colors |
| `colors.selection_fg` / `selection_bg` | string | Selection colors |
| `colors.ansi` / `brights` | table | 8-color ANSI palette |
| `colors.tab_bar` | table | Tab bar color overrides |
| `colors.split` | string | Pane split color |
| `force_reverse_video_cursor` | bool | Invert cursor colors |
| `inactive_pane_hsb` | table | `{hue, saturation, brightness}` for dimming |

### Cursor Options

| Option | Type | Description |
|--------|------|-------------|
| `default_cursor_style` | string | `"SteadyBlock"`, `"BlinkingBlock"`, `"SteadyUnderline"`, `"BlinkingUnderline"`, `"SteadyBar"`, `"BlinkingBar"` |
| `cursor_blink_rate` | int | Milliseconds (0 = no blink) |
| `cursor_blink_ease_in` / `ease_out` | string | Easing function |
| `cursor_thickness` | float | Thickness multiplier |
| `animation_fps` | int | Cursor animation framerate |

### Input & Keyboard Options

| Option | Type | Description |
|--------|------|-------------|
| `keys` | table | Key bindings `{key, mods, action}` |
| `key_tables` | table | Named key tables for modes |
| `leader` | table | `{key, mods, timeout_milliseconds}` |
| `mouse_bindings` | table | Mouse button bindings |
| `disable_default_key_bindings` | bool | Start with empty keymap |
| `disable_default_mouse_bindings` | bool | Start with empty mouse map |
| `enable_csi_u_key_encoding` | bool | Modern key encoding |
| `enable_kitty_keyboard` | bool | Kitty keyboard protocol |
| `use_ime` | bool | Enable input method editor |
| `debug_key_events` | bool | Log key events |
| `swap_backspace_and_delete` | bool | Swap BS/DEL |
| `send_composed_key_when_left_alt_is_pressed` | bool | macOS alt behavior |
| `send_composed_key_when_right_alt_is_pressed` | bool | macOS alt behavior |

### Scrolling & Selection

| Option | Type | Description |
|--------|------|-------------|
| `scrollback_lines` | int | Lines to keep (default 3500) |
| `enable_scroll_bar` | bool | Show scrollbar |
| `min_scroll_bar_height` | string | e.g. `"2cell"` |
| `scroll_to_bottom_on_input` | bool | Auto-scroll on input |
| `selection_word_boundary` | string | Characters that break word selection |
| `quick_select_alphabet` | string | Characters for quick select hints |
| `quick_select_patterns` | table | Regex patterns for quick select |

### Program & Shell Options

| Option | Type | Description |
|--------|------|-------------|
| `default_prog` | table | `{"/bin/zsh", "-l"}` |
| `default_cwd` | string | Starting directory |
| `default_domain` | string | Domain name |
| `default_workspace` | string | Initial workspace name |
| `launch_menu` | table | Launcher menu entries |
| `set_environment_variables` | table | `{VAR = "value", ...}` |
| `term` | string | `$TERM` value (default `"xterm-256color"`) |

### Domain Options

| Option | Type | Description |
|--------|------|-------------|
| `unix_domains` | table | Unix socket mux domains |
| `ssh_domains` | table | SSH connection domains |
| `wsl_domains` | table | WSL distribution domains |
| `tls_clients` / `tls_servers` | table | TLS mux connections |
| `ssh_backend` | string | `"Libssh"`, `"Ssh2"` |

### Behavior Options

| Option | Type | Description |
|--------|------|-------------|
| `automatically_reload_config` | bool | Hot reload on file change |
| `check_for_updates` | bool | Update notifications |
| `audible_bell` | string | `"Disabled"`, `"SystemBeep"` |
| `visual_bell` | table | Flash settings |
| `exit_behavior` | string | `"Close"`, `"Hold"`, `"CloseOnCleanExit"` |
| `exit_behavior_messaging` | string | Message on exit |
| `clean_exit_codes` | table | Exit codes considered clean |
| `status_update_interval` | int | Milliseconds for status updates |
| `hyperlink_rules` | table | URL detection patterns |
| `detect_password_input` | bool | Password input detection |
| `canonicalize_pasted_newlines` | string | `"None"`, `"LineFeed"`, `"CarriageReturn"`, `"CarriageReturnAndLineFeed"` |
| `unicode_version` | int | Unicode version for width |
| `unzoom_on_switch_pane` | bool | Unzoom when switching panes |

### Rendering & Performance

| Option | Type | Description |
|--------|------|-------------|
| `front_end` | string | `"WebGpu"`, `"OpenGL"`, `"Software"` |
| `webgpu_power_preference` | string | `"LowPower"`, `"HighPerformance"` |
| `max_fps` | int | Maximum framerate |
| `prefer_egl` | bool | Prefer EGL over GLX |
| `enable_wayland` | bool | Use Wayland if available |

### KeyAssignment Actions (for `action = ...`)

**Window/App:**
`ToggleFullScreen`, `Hide`, `Show`, `QuitApplication`, `ActivateWindow`, `ActivateWindowRelative`

**Tabs:**
`SpawnTab`, `ActivateTab(n)`, `ActivateTabRelative(n)`, `ActivateLastTab`, `CloseCurrentTab`, `MoveTab(n)`, `MoveTabRelative(n)`, `ShowTabNavigator`

**Panes:**
`SplitHorizontal`, `SplitVertical`, `SplitPane{direction, size, ...}`, `CloseCurrentPane`, `ActivatePaneDirection("Left"|"Right"|"Up"|"Down")`, `ActivatePaneByIndex(n)`, `TogglePaneZoomState`, `RotatePanes("Clockwise"|"CounterClockwise")`, `AdjustPaneSize("Left"|"Right"|"Up"|"Down", n)`, `PaneSelect{alphabet, mode}`

**Clipboard:**
`Copy`, `Paste`, `PasteFrom("Clipboard"|"PrimarySelection")`, `CopyTo("Clipboard"|"PrimarySelection"|"ClipboardAndPrimarySelection")`, `ClearSelection`

**Scrolling:**
`ScrollByLine(n)`, `ScrollByPage(n)`, `ScrollToTop`, `ScrollToBottom`, `ScrollToPrompt(n)`

**Font:**
`IncreaseFontSize`, `DecreaseFontSize`, `ResetFontSize`, `ResetFontAndWindowSize`

**Search/Select:**
`Search`, `QuickSelect`, `QuickSelectArgs{...}`, `CharSelect`, `ActivateCopyMode`

**Misc:**
`ShowLauncher`, `ShowLauncherArgs{flags}`, `ActivateCommandPalette`, `ShowDebugOverlay`, `ReloadConfiguration`, `ClearScrollback`, `ResetTerminal`, `SendString("text")`, `SendKey{key, mods}`, `EmitEvent("event-name")`, `Nop`, `DisableDefaultAssignment`, `Multiple{action1, action2, ...}`, `SwitchToWorkspace{name, spawn}`, `SwitchWorkspaceRelative(n)`

### wezterm Module Functions

**Config:**
`config_builder()`, `config_dir`, `config_file`

**Fonts:**
`font("Name", {weight="Bold", ...})`, `font_with_fallback({"Font1", "Font2"})`, `get_builtin_color_schemes()`

**Events:**
`on("event-name", function(window, pane) ... end)`, `emit("event-name", ...)`

**Actions:**
`action.ActionName`, `action_callback(function(window, pane) ... end)`

**Formatting:**
`format({...})`, `strftime(fmt)`, `strftime_utc(fmt)`, `pad_left(str, width)`, `pad_right(str, width)`, `truncate_left(str, width)`, `truncate_right(str, width)`

**System:**
`hostname()`, `home_dir`, `executable_dir`, `target_triple`, `version`, `running_under_wsl()`, `battery_info()`, `run_child_process(args)`, `background_child_process(args)`

**Data:**
`json_encode(value)`, `json_parse(str)`, `split_by_newlines(str)`, `column_width(str)`, `utf16_to_utf8(str)`

**Shell:**
`shell_split(str)`, `shell_join_args(table)`, `shell_quote_arg(str)`

**Files:**
`read_dir(path)`, `glob(pattern)`, `enumerate_ssh_hosts()`

**Logging:**
`log_info(msg)`, `log_warn(msg)`, `log_error(msg)`

**Utilities:**
`sleep_ms(ms)`, `nerdfonts`, `permute_any_mods(table)`, `permute_any_or_no_mods(table)`

### Event Hooks

| Event | Parameters | Purpose |
|-------|------------|---------|
| `gui-startup` | cmd | Initial window setup |
| `gui-attached` | domain | Domain attached |
| `mux-startup` | | Mux server startup |
| `update-status` | window, pane | Status bar updates |
| `update-right-status` | window, pane | Right status updates |
| `format-tab-title` | tab, tabs, panes, config, hover, max_width | Tab title formatting |
| `format-window-title` | tab, pane, tabs, panes, config | Window title |
| `window-config-reloaded` | window | Config reload notification |
| `window-focus-changed` | window, pane | Focus changed |
| `window-resized` | window, pane | Window resized |
| `bell` | window, pane | Bell triggered |
| `user-var-changed` | window, pane, name, value | User var changed |
| `open-uri` | window, pane, uri | URI opened |
| `new-tab-button-click` | window, pane, button, held_keys | New tab button clicked |

### Common Config Patterns

**Custom key binding:**
```lua
config.keys = {
  {key = "d", mods = "CMD", action = wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}},
  {key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane{confirm=false}},
}
```

**Leader key + table:**
```lua
config.leader = {key = "b", mods = "CTRL", timeout_milliseconds = 1000}
config.keys = {
  {key = "-", mods = "LEADER", action = wezterm.action.SplitVertical{domain="CurrentPaneDomain"}},
}
```

**Key tables (modal keys):**
```lua
config.key_tables = {
  resize_pane = {
    {key = "h", action = wezterm.action.AdjustPaneSize{"Left", 1}},
    {key = "Escape", action = "PopKeyTable"},
  },
}
config.keys = {
  {key = "r", mods = "LEADER", action = wezterm.action.ActivateKeyTable{name="resize_pane", one_shot=false}},
}
```

**Dynamic status bar:**
```lua
wezterm.on("update-status", function(window, pane)
  window:set_right_status(wezterm.format({
    {Foreground = {Color = "#808080"}},
    {Text = wezterm.strftime("%H:%M")},
  }))
end)
```

**Custom tab title:**
```lua
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = tab.active_pane.title
  if tab.is_active then
    return {{Background = {Color = "#1a1b26"}}, {Text = " " .. title .. " "}}
  end
  return " " .. title .. " "
end)
```

**Font with fallback:**
```lua
config.font = wezterm.font_with_fallback({
  "JetBrains Mono",
  "Symbols Nerd Font Mono",
  "Noto Color Emoji",
})
```

**Conditional config (per-OS):**
```lua
if wezterm.target_triple:find("darwin") then
  config.font_size = 14
elseif wezterm.target_triple:find("windows") then
  config.default_prog = {"pwsh.exe"}
end
```

**Background image:**
```lua
config.background = {
  {source = {File = "/path/to/image.png"}, hsb = {brightness = 0.02}},
  {source = {Color = "#1a1b26"}, width = "100%", height = "100%", opacity = 0.9},
}
```

**SSH domain:**
```lua
config.ssh_domains = {
  {name = "server", remote_address = "user@host", username = "user"},
}
```

### FormatItem Types (for wezterm.format)

- `{Text = "string"}` - Plain text
- `{Foreground = {Color = "#hex"}}` - Text color
- `{Background = {Color = "#hex"}}` - Background color
- `{Foreground = {AnsiColor = "Red"}}` - ANSI color
- `{Attribute = {Intensity = "Bold"}}` - Bold
- `{Attribute = {Italic = true}}` - Italic
- `{Attribute = {Underline = "Single"}}` - Underline
- `"ResetAttributes"` - Reset formatting

## Resources

- [WezTerm Documentation](https://wezterm.org/)
- [WezTerm GitHub](https://github.com/wezterm/wezterm)
- [Config Options Reference](https://wezterm.org/config/lua/config/index.html)
- [KeyAssignment Reference](https://wezterm.org/config/lua/keyassignment/index.html)
- [Awesome WezTerm Plugins](https://github.com/michaelbrusegard/awesome-wezterm)
- [Smart Workspace Switcher](https://github.com/MLFlexer/smart_workspace_switcher.wezterm)
