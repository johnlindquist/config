#!/bin/bash

# Safe script to fix Mission Control space display sync

# Script setup
SCRIPT_NAME="fix_space_display_safe.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# Use absolute paths
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
OSA="/usr/bin/osascript"

echo "Safely fixing Mission Control space display..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Starting Mission Control space display fix"

# 1. Get current space info
echo "Current spaces:"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Querying current spaces"
$YABAI -m query --spaces | $JQ -r '.[] | "Space \(.index) on display \(.display): \(.windows | length) windows"' | while read line; do
    echo "$line"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "$line"
done

# 2. Add descriptive labels to all spaces
echo -e "\nAdding labels to spaces..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Adding descriptive labels to all spaces"
$YABAI -m query --spaces | $JQ -r '.[] | .index' | while read -r idx; do
    window_count=$($YABAI -m query --windows --space "$idx" | $JQ 'length')
    label="Desktop $idx ($window_count windows)"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Setting label for space $idx: $label"
    $YABAI -m space "$idx" --label "$label"
done

# 3. Trigger Mission Control refresh without killing Dock
echo -e "\nRefreshing Mission Control..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Triggering Mission Control refresh via AppleScript"
# Use AppleScript to open Mission Control
$OSA << 'EOF' 2>&1 | while read line; do
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "AppleScript output: $line"
done
tell application "System Events"
    -- Open Mission Control
    key code 160
    delay 0.5
    -- Close Mission Control
    key code 53
end tell
EOF

# Sleep briefly to ensure changes take effect
sleep 0.5

# 4. Show updated state
echo -e "\nUpdated spaces:"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Displaying updated space state"
$YABAI -m query --spaces | $JQ -r '.[] | "Space \(.index) [\(.label)]: \(.windows | length) windows"' | while read line; do
    echo "$line"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "$line"
done

echo -e "\nMission Control should now show correct window counts."
echo "If Desktop 1 still shows as empty, try:"
echo "  1. Open Mission Control manually (F3 or swipe up with 3 fingers)"
echo "  2. Click on Desktop 1"
echo "  3. If still broken, run: killall Dock"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mission Control fix completed"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"