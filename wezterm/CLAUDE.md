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

## Resources

- [WezTerm Documentation](https://wezterm.org/)
- [WezTerm GitHub](https://github.com/wezterm/wezterm)
- [Awesome WezTerm Plugins](https://github.com/michaelbrusegard/awesome-wezterm)
- [Smart Workspace Switcher](https://github.com/MLFlexer/smart_workspace_switcher.wezterm)
