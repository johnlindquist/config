#!/bin/bash
# wezterm_trigger.sh - Focus WezTerm and trigger an action (FAST version)
#
# Usage: wezterm_trigger.sh <action>
#
# Available actions:
#   quick_open        - Open the Quick Open picker (Cmd+P equivalent)
#   quick_open_cursor - Open Quick Open in Cursor mode (Cmd+Shift+P equivalent)
#   workspaces        - Open the workspace picker
#   command_palette   - Open the command palette
#   launcher          - Open the launcher
#   shortcuts         - Show keyboard shortcuts
#   themes            - Open the theme picker
#   layouts           - Open the layout picker
#   zen               - Toggle zen mode
#   app_launcher      - Open the app launcher (all installed apps)

ACTION="$1"
TRIGGER_FILE="/tmp/wezterm.trigger"

[[ -z "$ACTION" ]] && exit 1

# Write trigger FIRST (before focus, so it's ready when window-focus-changed fires)
printf "%s" "$ACTION" > "$TRIGGER_FILE"

# Use open -a (faster than osascript)
open -a WezTerm
