#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="move_window_west.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# Function to log current state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local window_id=$(yabai -m query --windows --window | jq -r '.id')
    local space_id=$(yabai -m query --spaces --space | jq -r '.index')
    local display_id=$(yabai -m query --displays --display | jq -r '.index')
    local window_info=$(yabai -m query --windows --window $window_id | jq -c '.')
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
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to move window west (or equivalent for vertical)."

# Main logic starts
CUR_WIN_ID=$(yabai -m query --windows --window | jq '.id')
CUR_DISPLAY_ID=$(yabai -m query --windows --window $CUR_WIN_ID | jq '.display')
CUR_SPACE_ID=$(yabai -m query --windows --window $CUR_WIN_ID | jq '.space')

# Actual command to move the window west
if [[ -n "$CUR_WIN_ID" && "$CUR_WIN_ID" != "null" ]]; then
    yabai -m window --warp west
    # Optionally, re-focus the window if warp doesn't maintain focus (Yabai usually does)
    # yabai -m window --focus "$CUR_WIN_ID"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION_DETAIL" "Executed: yabai -m window --warp west for window $CUR_WIN_ID"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get current window ID to move west. CUR_WIN_ID: '$CUR_WIN_ID'"
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0 