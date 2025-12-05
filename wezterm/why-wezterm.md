# Why WezTerm: The AI-Native Terminal for the Agentic Era

## The Thesis

We are entering an era where AI agents can read, write, and modify configuration files on your behalf. In this new paradigm, **the best tool is no longer the one with the prettiest GUI or the most menu options—it's the one with the most programmable surface area.**

WezTerm is that tool for terminals.

## The Terminal Landscape in 2025

| Terminal | Configuration | Scriptable Actions | AI-Friendly |
|----------|--------------|-------------------|-------------|
| **iTerm2** | Plist/GUI | AppleScript (limited) | ❌ Binary prefs |
| **Alacritty** | YAML | None | ⚠️ Config only |
| **Kitty** | Custom format | Limited scripting | ⚠️ Partial |
| **Hyper** | JavaScript | Plugin system | ⚠️ Electron bloat |
| **Terminal.app** | Plist/GUI | AppleScript | ❌ Binary prefs |
| **WezTerm** | **Lua** | **Full Lua runtime** | ✅ **Complete** |

The difference isn't incremental. It's categorical.

## What Makes WezTerm Different

### 1. Configuration IS Code

Most terminals separate "configuration" from "behavior." You set some options in a config file, and that's it. WezTerm's config file is a **full Lua program** that executes when the terminal starts.

```lua
-- This isn't configuration. This is code.
local function smart_split(window, pane)
  local dims = pane:get_dimensions()
  if dims.cols > dims.viewport_rows * 2.2 then
    pane:split({ direction = "Right", size = 0.5 })
  else
    pane:split({ direction = "Bottom", size = 0.5 })
  end
end
```

An AI can write this. An AI can modify this. An AI can extend this. Try doing that with iTerm2's binary preference files.

### 2. Runtime Access to Everything

WezTerm exposes its entire internal state to Lua:

- **Panes**: Query dimensions, running processes, working directories
- **Tabs**: List panes, get/set titles, manage layouts  
- **Windows**: Control appearance, override settings dynamically
- **Events**: React to focus changes, key presses, window resizes
- **External tools**: Shell out to any CLI tool (`zoxide`, `git`, `fzf`)

```lua
-- Query the current process to change behavior
local function is_vim(pane)
  local process = pane:get_foreground_process_info()
  return process and process.executable:find("vim") ~= nil
end

-- Now keybindings can be context-aware
if is_vim(pane) then
  -- Pass through to Vim
else
  -- Handle in WezTerm
end
```

### 3. Action Callbacks: Where AI Shines

The killer feature is `wezterm.action_callback()`. Any keybinding can execute arbitrary Lua code:

```lua
{
  key = "d",
  mods = "CMD",
  action = wezterm.action_callback(function(window, pane)
    -- Literally any logic you want
    -- An AI can write this for you based on your description
  end),
}
```

This is the unlock. When you say to an AI:

> "Make Cmd+D create smart splits that respect a layout mode like Zellij"

The AI can actually implement that. Not "here's how you'd do it if WezTerm supported it" but actual working code that does exactly what you asked.

### 4. Event-Driven Architecture

WezTerm fires events that you can hook into:

```lua
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  -- Complete control over tab rendering
end)

wezterm.on('update-status', function(window, pane)
  -- Build any status bar you want
end)

wezterm.on('window-resized', function(window, pane)
  -- React to window changes
end)
```

Every event is a hook where AI-generated code can live.

## The AI Advantage

### Before: The GUI Trap

Traditional workflow for customizing iTerm2:
1. Open Preferences
2. Click through tabs
3. Find the setting (if it exists)
4. Toggle it
5. Realize you need something more complex
6. Search for "iTerm2 smart splits"
7. Find out it's not possible
8. Give up or switch tools

### After: The Conversational Workflow

WezTerm workflow with AI:
1. Tell AI what you want
2. AI writes the Lua code
3. Paste into config
4. Reload
5. It works (or AI debugs it)

**The terminal becomes as customizable as your imagination.**

### Real Examples from This Config

Every one of these features was built by describing the desired behavior:

| Request | Result |
|---------|--------|
| "Zellij-style layout modes" | 200 lines of layout management code |
| "Fuzzy tab picker showing directory and process" | Custom InputSelector with dynamic choices |
| "Status bar showing layout mode, workspace, and time" | Event handler with formatted segments |
| "Cmd+T should open zoxide picker in new tab" | Chained actions: spawn tab → query zoxide → show picker |
| "Different color schemes per project directory" | Dynamic config overrides based on cwd |

None of these are "features" of WezTerm. They're **programs** that run inside WezTerm.

## Why Not the Others?

### iTerm2
The gold standard for macOS terminals, but:
- Configuration stored in binary plists
- AppleScript integration is clunky and limited
- No way to script pane/tab behavior
- AI would need to generate AppleScript + GUI instructions

### Alacritty
Fast and minimal, but:
- YAML config only—no scripting
- No event system
- No action callbacks
- AI can only change static settings

### Kitty
Closer to WezTerm in capability, but:
- Custom config format (not a real language)
- Scripting requires external "kittens" (Python scripts)
- Less cohesive API
- Split between config file and external scripts

### Hyper
JavaScript-based, which sounds good, but:
- Electron-based (resource heavy)
- Plugin system is more about theming
- Less terminal-native functionality
- Performance issues

## The Compounding Effect

Here's what happens over time:

**Month 1**: You ask AI to set up basic splits and styling.

**Month 3**: You've accumulated custom layouts, smart navigation, project-specific configs.

**Month 6**: Your terminal has features that don't exist in any other terminal—because you (with AI) invented them.

**Month 12**: Your WezTerm config is a personalized terminal multiplexer that exactly matches your workflow.

This is only possible when the tool is programmable enough to grow with you.

## The Future is Scriptable

We're moving toward a world where:

1. **AI agents edit config files** as part of their workflow
2. **Natural language becomes the interface** for customization
3. **The best tools are the most AI-accessible** ones

WezTerm is built for this future:

- **Plain text config**: AI can read and write it
- **Real programming language**: AI can reason about it
- **Full API access**: AI can build anything
- **Event system**: AI can react to anything
- **No GUI dependency**: Everything is code

## Conclusion

The question isn't "which terminal has the best features today?"

The question is "which terminal can have any feature I need tomorrow?"

With GUI-based terminals, you're limited to what the developers imagined. With WezTerm, you're limited only by what you can describe—and AI can describe a lot.

**WezTerm isn't just a terminal. It's a terminal construction kit. And in the age of AI, that's exactly what you want.**

---

## Getting Started

1. Install WezTerm: `brew install --cask wezterm`
2. Create `~/.config/wezterm/wezterm.lua`
3. Start with the config in this repo
4. Ask an AI to customize it for you

The future of terminal customization is conversational. WezTerm is ready for it.
