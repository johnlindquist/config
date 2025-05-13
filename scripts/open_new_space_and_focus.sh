#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="open_new_space_and_focus.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Function to log relevant state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local current_space_info=$($YABAI_PATH -m query --spaces --space | $JQ_PATH -c '.' 2>/dev/null || echo "failed query space")
    local current_display_info=$($YABAI_PATH -m query --displays --display | $JQ_PATH -c '.' 2>/dev/null || echo "failed query display")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Current Space: $current_space_info, Current Display: $current_display_info"
}

# Log state before action
log_state "BEFORE_STATE"

# --- Script Logic ---
# Get current display
current_display=$($YABAI_PATH -m query --displays --display | $JQ_PATH '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current display index: $current_display"

# Create a new space on the current display
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Creating new space on display $current_display."
$YABAI_PATH -m space --create
create_exit_code=$?

if [[ $create_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to create space (Exit code: $create_exit_code). Aborting focus attempt."
    log_state "AFTER_STATE"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with error."
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Space created successfully. Finding index of the new space."

# Find the index of the last space on the current display (which should be the new one)
last_space_index=$($YABAI_PATH -m query --spaces --display "$current_display" | $JQ_PATH 'map(.index) | max')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Index of newly created space: $last_space_index"

# Focus the new space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing new space index $last_space_index."
$YABAI_PATH -m space --focus "$last_space_index"
focus_exit_code=$?

if [[ $focus_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to focus new space $last_space_index (Exit code: $focus_exit_code)."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused new space $last_space_index."
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
final_exit_code=$([[ $create_exit_code -ne 0 || $focus_exit_code -ne 0 ]] && echo 1 || echo 0)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $final_exit_code."

exit $final_exit_code 