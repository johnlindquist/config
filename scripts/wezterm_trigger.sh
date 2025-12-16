#!/bin/bash
# wezterm_trigger.sh - Focus WezTerm and trigger an action via the file-based trigger system
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
#
# Example Karabiner integration:
#   [:launch+t [:!launch "wezterm_trigger.sh" "quick_open"]]

ACTION="$1"
TRIGGER_FILE="/tmp/wezterm.trigger"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <action>" >&2
  echo "Actions: quick_open, quick_open_cursor, workspaces, command_palette, launcher, shortcuts, themes, layouts, zen" >&2
  exit 1
fi

# Write the trigger file BEFORE activating WezTerm
# This ensures the trigger is ready when WezTerm's update-status fires
printf "%s" "$ACTION" > "$TRIGGER_FILE"

# Activate WezTerm (brings to front)
osascript -e 'tell application "WezTerm" to activate'

# The trigger will be processed by WezTerm's update-status event handler
# within ~1 second (the default status_update_interval)
