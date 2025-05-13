#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="move_window_east.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# Function to log current state (assuming similar needs to west)
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local window_id=$(yabai -m query --windows --window | jq -r '.id' 2>/dev/null || echo "unknown")
    local space_id=$(yabai -m query --spaces --space | jq -r '.index' 2>/dev/null || echo "unknown")
    local display_id=$(yabai -m query --displays --display | jq -r '.index' 2>/dev/null || echo "unknown")
    local window_info="unknown"
    if [[ "$window_id" != "unknown" ]]; then
        window_info=$(yabai -m query --windows --window $window_id | jq -c '.' 2>/dev/null || echo "failed to query window")
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
CUR_WIN_ID=$(yabai -m query --windows --window | jq '.id')
CUR_DISPLAY_ID=$(yabai -m query --windows --window $CUR_WIN_ID | jq '.display')
CUR_SPACE_ID=$(yabai -m query --windows --window $CUR_WIN_ID | jq '.space')

# ... existing code ...

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0 