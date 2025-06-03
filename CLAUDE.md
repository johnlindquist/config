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