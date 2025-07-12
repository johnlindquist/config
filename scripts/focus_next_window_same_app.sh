#!/usr/bin/env bash

# ---------- focus_next_window_same_app.sh ----------
# This script focuses on the next window of the currently focused app
# Similar to cmd+` on macOS but works across spaces instantly

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="focus_next_window_same_app.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# Use absolute paths for yabai and jq
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local window_id=$($YABAI -m query --windows --window | $JQ -r '.id' 2>/dev/null || echo "unknown")
    local app_name=$($YABAI -m query --windows --window | $JQ -r '.app' 2>/dev/null || echo "unknown")
    local space_id=$($YABAI -m query --spaces --space | $JQ -r '.index' 2>/dev/null || echo "unknown")
    local display_id=$($YABAI -m query --displays --display | $JQ -r '.index' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, App: $app_name, Space: $space_id, Display: $display_id"
}

# Log state before action
log_state "BEFORE_STATE"

# Get current window information
CURRENT_WINDOW=$($YABAI -m query --windows --window)
if [[ -z "$CURRENT_WINDOW" || "$CURRENT_WINDOW" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No focused window found"
    exit 1
fi

CURRENT_WINDOW_ID=$(echo "$CURRENT_WINDOW" | $JQ -r '.id')
CURRENT_APP=$(echo "$CURRENT_WINDOW" | $JQ -r '.app')

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current window ID: $CURRENT_WINDOW_ID, App: $CURRENT_APP"

# Get all windows of the same app across all spaces
ALL_APP_WINDOWS=$($YABAI -m query --windows | $JQ --arg app "$CURRENT_APP" '[.[] | select(.app == $app and .["is-minimized"] == false)] | sort_by(.id)')

# Get count of windows
WINDOW_COUNT=$(echo "$ALL_APP_WINDOWS" | $JQ 'length')

if [[ "$WINDOW_COUNT" -le 1 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Only one window found for app: $CURRENT_APP"
    exit 0
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Found $WINDOW_COUNT windows for app: $CURRENT_APP"

# Find current window index in the array
CURRENT_INDEX=$(echo "$ALL_APP_WINDOWS" | $JQ --arg id "$CURRENT_WINDOW_ID" 'to_entries | .[] | select(.value.id == ($id | tonumber)) | .key')

if [[ -z "$CURRENT_INDEX" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not find current window in app windows list"
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current window index: $CURRENT_INDEX"

# Calculate next index (wrap around to 0 if at end)
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % WINDOW_COUNT ))

# Get next window ID
NEXT_WINDOW_ID=$(echo "$ALL_APP_WINDOWS" | $JQ -r ".[$NEXT_INDEX].id")
NEXT_WINDOW_SPACE=$(echo "$ALL_APP_WINDOWS" | $JQ -r ".[$NEXT_INDEX].space")

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Switching to next window: ID=$NEXT_WINDOW_ID, Space=$NEXT_WINDOW_SPACE"

# Focus the next window
$YABAI -m window --focus $NEXT_WINDOW_ID
focus_exit=$?

if [[ $focus_exit -eq 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused window $NEXT_WINDOW_ID"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to focus window $NEXT_WINDOW_ID (exit code: $focus_exit)"
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"

exit $focus_exit