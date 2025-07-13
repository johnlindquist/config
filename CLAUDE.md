# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a macOS dotfiles repository focused on window management automation and developer productivity tools. The repository is tracked with git and contains configurations for various applications and utilities.

## Key Components

### Window Management System (Yabai + Scripts)
The core of this repository is an extensive Yabai window management system with 40+ automation scripts in `/scripts/`:
- Window movement: `move_window_*.sh`, `move-window-east.sh`, `move-window-west.sh`
- Space management: `space_*.sh`, `remove_empty_spaces.sh`
- Display management: `move_to_*_display.sh`
- Logging system: `log_helper.sh`, `log_yabai_focus.sh`

### Karabiner Complex Modifications
Extensive keyboard customization in `karabiner/karabiner.json` with multiple modes:
- escape-mode, button2-mode, button4-mode, button5-mode
- Integration with Yabai scripts for window management hotkeys

## Common Commands

### Script Execution
All window management scripts are in `~/.config/scripts/`:
```bash
# Example: Move window east
~/.config/scripts/move_window_east.sh

# Fix floating windows
~/.config/scripts/fix_floats.sh

# Remove empty spaces
~/.config/scripts/remove_empty_spaces.sh
```

### Yabai Commands
```bash
# Restart Yabai service
yabai --restart-service

# Query current window
/opt/homebrew/bin/yabai -m query --windows --window

# Focus window by ID
/opt/homebrew/bin/yabai -m window --focus [WINDOW_ID]
```

### Debugging
Scripts use a centralized logging system via `log_helper.sh`. Logs are written to `~/.config/logs/`.

## Architecture Notes

### Script Architecture
- All scripts follow a consistent pattern with debug logging
- Scripts use absolute paths: `/opt/homebrew/bin/yabai`, `/opt/homebrew/bin/jq`
- Error handling with proper exit codes
- Centralized logging through `log_helper.sh`

### Yabai Integration
- Window focus history tracked in `~/.cache/yabai_focus_history.log`
- Yabai signals configured to trigger scripts on window events
- Scripts handle floating windows, space management, and display coordination

### Development Preferences (from Cursor rules)
- Package manager: `pnpm`
- Testing: `vitest` with single-run mode and bail=1
- Formatting/Linting: `@biomejs/biome`
- TypeScript runner: `tsx`
- Git commits: Use fix/feat/chore prefixes
- Aggressive proactive development approach
- Many small files over large ones
- Excessive logging for observability

## Important Files
- `karabiner/karabiner.json` - Keyboard customization (530KB)
- `scripts/log_yabai_focus.sh` - Window focus tracking
- `docs/yabai-focus-tracking-setup.md` - Comprehensive Yabai setup guide
- `.cursor/rules/_global.mdc` - Global development preferences

## Yabai Nuances
- Ensure window focus tracking scripts are always running
- Be mindful of floating window behavior
- Check signal configurations before making changes
- Monitor Yabai logs for unexpected window management issues
- Validate window ID consistency across scripts
- Test scripts in different display and space configurations

## Lessons Learned

### Bash Arithmetic with Floating Point Numbers (FAILED)
**What failed:** Using bash arithmetic operations `$(( ))` with yabai's floating-point coordinates
```bash
# This fails because bash doesn't support floats
CURRENT_RIGHT_EDGE=$((CURRENT_X + CURRENT_WIDTH))
```
**What worked:** Do all arithmetic in jq instead
```bash
CURRENT_RIGHT_EDGE=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.x + .frame.w')
```

### Window Borders with JankyBorders
**Package name:** The tool is installed as `borders` not `jankyborders`
```bash
brew install felixkratz/formulae/borders  # Correct
brew install jankyborders                 # Wrong
```

**Border clipping on maximized windows:**
- Issue: Borders get clipped at screen edges when windows are maximized
- Partial solution: Use undocumented `order=above` option
- Note: JankyBorders only supports full borders (all 4 sides), not partial borders

**What doesn't work:**
- Adding padding only to focused window (yabai padding is global)
- Creating bottom-only borders (JankyBorders limitation)
- Perfect border rendering with `order=above` (minor 1px corner issues)

### Cross-Display Window Focus
**What worked:** Successfully implemented cross-display focus for all directions (north/south/east/west)
- East/West: Focus the edge window closest to current position
- North/South: Focus the largest window or edge window on target display
- Use display frame coordinates to determine spatial relationships

### Script Consolidation Pattern
**What worked:** Creating a single parametric script instead of multiple similar scripts
- `focus_direction.sh [east|west|north|south]` replaces 4 separate scripts
- Original scripts can delegate to the consolidated script for backward compatibility

### Chrome Tab Detachment
**What worked:** Using AppleScript to get tab URL, close tab, and create new window
- Check for single tab to avoid closing window
- Return meaningful status messages for logging

### Yabai Window Rules for App Placement
**What worked:** Using yabai rules to automatically place apps on specific displays/spaces
```bash
yabai -m rule --add app="^AppName$" display=4 space=12 manage=on grid=1:2:0:0:1:1
```
- Grid syntax: `rows:cols:start-x:start-y:width:height` (e.g., `1:2:0:0:1:1` = left half)
- Rules apply to NEW windows only (not existing ones)
- Must use exact app name with `^` and `$` anchors

### Empty Space Detection Issues
**Original script limitation:** `first-window == 0` check misses spaces with hidden system windows

**Hidden system windows that cause false positives:**
- Granola app (no role, can't move)
- Music app (no role, can't move)
- UAD Meter (hidden but has window ID)

**What worked:** Check for truly visible windows instead:
- Verify window has a valid `role` (not null/empty)
- Check `can-move` property
- Ignore system windows without proper roles

**Bash counter bug in pipes:** Variables incremented in piped while loops are in subshells
```bash
# FAILED: Counter always shows 0
echo "$items" | while read item; do ((count++)); done

# WORKED: Use arrays or for loops
for item in $items; do ((count++)); done
# OR use arrays: destroyed_spaces+=("$space_index")
```

### Mission Control Sync Issues
**Problem:** After programmatically creating/destroying spaces, Mission Control can show incorrect space contents

**Symptoms:**
- "Desktop 1" appears empty in Mission Control but has windows
- Space indices don't match between yabai and Mission Control

**Partial fixes:**
1. Restart Dock: `killall Dock`
2. Force Mission Control refresh via AppleScript
3. Add/remove space labels to trigger update
4. Nuclear option: `rm ~/Library/Preferences/com.apple.spaces.plist && killall Dock`

**Root cause:** yabai uses undocumented APIs, causing occasional desync with macOS

### Yabai Service Management
**What failed:** `brew services restart yabai` (yabai doesn't use brew services)

**What worked:** 
- `yabai --restart-service` (built-in command)
- Check logs: `~/.cache/yabai_script_log.log`

### Script Naming Patterns
- Use underscores for consistency: `remove_empty_spaces.sh`
- Create "improved" versions when fixing complex issues: `remove_empty_spaces_improved.sh`
- Consolidate similar scripts: `focus_direction.sh` with parameters