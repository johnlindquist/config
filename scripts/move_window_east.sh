#!/usr/bin/env bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="move_window_east.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started. PATH: $PATH"

# Use absolute paths for yabai and jq
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state (assuming similar needs to west)
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local window_id=$($YABAI -m query --windows --window | $JQ -r '.id' 2>/dev/null || echo "unknown")
    local space_id=$($YABAI -m query --spaces --space | $JQ -r '.index' 2>/dev/null || echo "unknown")
    local display_id=$($YABAI -m query --displays --display | $JQ -r '.index' 2>/dev/null || echo "unknown")
    local window_info="unknown"
    if [[ "$window_id" != "unknown" ]]; then
        window_info=$($YABAI -m query --windows --window $window_id | $JQ -c '.' 2>/dev/null || echo "failed to query window")
    fi
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Space: $space_id, Display: $display_id, Details: $window_info"
}

# Log state before action
log_state "BEFORE_STATE"

# Source common functions if they exist
# COMMON_SCRIPT_PATH="$(dirname "$0")/common_yabai_funcs.sh"
# if [[ -f "$COMMON_SCRIPT_PATH" ]]; then
#     source "$COMMON_SCRIPT_PATH"
# fi

# Function to get display arrangement (e.g., "horizontal" or "vertical")
# Placeholder: Implement or source this function if needed
# get_display_arrangement() { echo "horizontal"; }

# Log action
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to move window east (or equivalent for vertical)."

# Main logic starts
CUR_WIN_ID=$($YABAI -m query --windows --window | $JQ '.id')
CUR_DISPLAY_ID=$($YABAI -m query --windows --window $CUR_WIN_ID | $JQ '.display')
CUR_SPACE_ID=$($YABAI -m query --windows --window $CUR_WIN_ID | $JQ '.space')

# Actual command to move the window east
if [[ -n "$CUR_WIN_ID" && "$CUR_WIN_ID" != "null" ]]; then
    $YABAI -m window --warp east
    # Optionally, re-focus the window if warp doesn't maintain focus (Yabai usually does)
    # yabai -m window --focus "$CUR_WIN_ID"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION_DETAIL" "Executed: yabai -m window --warp east for window $CUR_WIN_ID"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get current window ID to move east. CUR_WIN_ID: '$CUR_WIN_ID'"
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0 