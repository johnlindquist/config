#!/bin/bash

# Comprehensive script to fix Mission Control display issues

# Script setup
SCRIPT_NAME="reset_spaces_display.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# Use absolute paths
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
OSA="/usr/bin/osascript"

echo "Fixing Mission Control space display issues..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Starting comprehensive Mission Control fix"

# Function to log current state
log_state() {
    local type="$1"
    local space_count=$($YABAI -m query --spaces 2>/dev/null | $JQ 'length' 2>/dev/null || echo "unknown")
    local display_count=$($YABAI -m query --displays 2>/dev/null | $JQ 'length' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "SpaceCount: $space_count, DisplayCount: $display_count"
}

# Log state before action
log_state "BEFORE_STATE"

# 1. Reset Mission Control cache
echo "Resetting Mission Control cache..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Resetting Mission Control cache files"
rm -f ~/Library/Preferences/com.apple.spaces.plist 2>/dev/null && \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Removed com.apple.spaces.plist" || \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "com.apple.spaces.plist not found"
rm -f ~/Library/Preferences/com.apple.dock.plist 2>/dev/null && \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Removed com.apple.dock.plist" || \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "com.apple.dock.plist not found"

# 2. Kill relevant processes
echo "Restarting system UI processes..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Killing system UI processes"
killall Dock && "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Killed Dock"
killall "Mission Control" 2>/dev/null && \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Killed Mission Control" || \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Mission Control not running"
killall ControlCenter 2>/dev/null && \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Killed ControlCenter" || \
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "ControlCenter not running"

# Wait for processes to restart
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Waiting 3 seconds for processes to restart"
sleep 3

# 3. Reset space names/labels
echo "Resetting space labels..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Resetting space labels"
$YABAI -m query --spaces | $JQ -r '.[].index' | while read -r idx; do
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Setting label for space $idx"
    $YABAI -m space "$idx" --label "Desktop $idx"
    sleep 0.1
done

# 4. Force Mission Control to rebuild its cache
echo "Forcing Mission Control to rebuild..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Forcing Mission Control to rebuild cache"
# Open and close Mission Control programmatically
$OSA -e 'tell application "Mission Control" to launch' 2>&1 | while read line; do
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "AppleScript launch output: $line"
done
sleep 1
$OSA -e 'tell application "System Events" to key code 53' 2>&1 | while read line; do
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "AppleScript close output: $line"
done

# 5. Restart yabai
echo "Restarting yabai..."
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Restarting yabai service"
$YABAI --restart-service 2>&1 | while read line; do
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Yabai restart output: $line"
done

# Wait for yabai to restart
sleep 2

# Log state after action
log_state "AFTER_STATE"

echo "Fix complete. Please check Mission Control now."
echo "If the issue persists, you may need to log out and back in."

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mission Control reset completed"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"