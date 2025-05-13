#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="manage_space_on_mouse_display.sh"

ACTION="$1"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started. Action: $ACTION"

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"
# CLICLICK_PATH="/opt/homebrew/bin/cliclick" # No longer needed for logging

# Validate action
if [[ "$ACTION" != "left" && "$ACTION" != "right" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Invalid action: '$ACTION'. Usage: $0 [left|right]"
  exit 1
fi

# Function to log relevant state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local mouse_loc=$($YABAI_PATH -m query --mouse 2>/dev/null || echo '{"x":-1,"y":-1}') # Query mouse location safely
    local mouse_x=$(echo "$mouse_loc" | $JQ_PATH -r '.x')
    local mouse_y=$(echo "$mouse_loc" | $JQ_PATH -r '.y')
    local displays_info=$($YABAI_PATH -m query --displays | $JQ_PATH -c '.' 2>/dev/null || echo "[]")
    local mouse_display_info=$($YABAI_PATH -m query --displays | $JQ_PATH -r --argjson x "$mouse_x" --argjson y "$mouse_y" '.[] | select(.frame.x <= $x and .frame.y <= $y and .frame.x + .frame.w > $x and .frame.y + .frame.h > $y)' 2>/dev/null)
    local focused_display_info=$($YABAI_PATH -m query --displays | $JQ_PATH -r '.[] | select(.has_focus == true)' 2>/dev/null)
    local mouse_display_index=$(echo "$mouse_display_info" | $JQ_PATH -r '.index' 2>/dev/null || echo "unknown_mouse")
    local focused_display_index=$(echo "$focused_display_info" | $JQ_PATH -r '.index' 2>/dev/null || echo "unknown_focus")
    local spaces_info=$($YABAI_PATH -m query --spaces | $JQ_PATH -c '.' 2>/dev/null || echo "[]")
    local current_space_index=$($YABAI_PATH -m query --spaces --space | $JQ_PATH -r '.index' 2>/dev/null || echo "unknown")

    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Mouse($mouse_x,$mouse_y) on Display: $mouse_display_index, Focused Display: $focused_display_index, Current Space: $current_space_index, All Displays: $displays_info, All Spaces: $spaces_info"
}

# Log state before action
log_state "BEFORE_STATE"


# --- Script Logic ---

# 1. Determine Target Display (based on mouse)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Determining display under mouse pointer."
mouse_loc=$($YABAI_PATH -m query --mouse)
mouse_x=$(echo "$mouse_loc" | $JQ_PATH -r '.x')
mouse_y=$(echo "$mouse_loc" | $JQ_PATH -r '.y')
target_display_info=$($YABAI_PATH -m query --displays | $JQ_PATH -r --argjson x "$mouse_x" --argjson y "$mouse_y" '.[] | select(.frame.x <= $x and .frame.y <= $y and .frame.x + .frame.w > $x and .frame.y + .frame.h > $y) | .' 2>/dev/null)

if [[ -z "$target_display_info" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not determine the display under mouse coordinates ($mouse_x, $mouse_y)."
    exit 1
fi
target_display_index=$(echo "$target_display_info" | $JQ_PATH -r '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mouse is on display index: $target_display_index. Frame: $(echo "$target_display_info" | $JQ_PATH -c '.frame')"

# 2. Attempt to Focus Display Under Mouse
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to focus display index $target_display_index using 'yabai -m display --focus $target_display_index' (instead of potentially unreliable 'mouse' selector)."
"$YABAI_PATH" -m display --focus "$target_display_index"
focus_exit_code=$?

if [[ $focus_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Focusing display $target_display_index failed (Exit code: $focus_exit_code). Attempting space change anyway."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused display $target_display_index."
fi

# 3. Perform Space Change
space_change_direction="unknown"
if [[ "$ACTION" == "left" ]]; then
  space_change_direction="prev"
elif [[ "$ACTION" == "right" ]]; then
  space_change_direction="next"
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to focus space '$space_change_direction' on the (intended) focused display $target_display_index."
"$YABAI_PATH" -m space --focus "$space_change_direction"
space_change_exit_code=$?

if [[ $space_change_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Focusing space '$space_change_direction' failed (Exit code: $space_change_exit_code)."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Space change command '$space_change_direction' executed successfully."
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0 