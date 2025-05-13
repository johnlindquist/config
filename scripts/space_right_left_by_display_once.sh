#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="space_right_left_by_display_once.sh"
ACTION="$1"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started. Action: $ACTION"

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"
CLICLICK_PATH="/opt/homebrew/bin/cliclick"

# Validate action
if [[ "$ACTION" != "left" && "$ACTION" != "right" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Invalid action: '$ACTION'. Usage: $0 [left|right]"
    exit 1
fi

# Function to log relevant state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local mouse_loc=$($YABAI_PATH -m query --mouse 2>/dev/null || echo '{"x":-1,"y":-1}')
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
# Get display containing the mouse
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Determining display under mouse."
mouse_loc=$($YABAI_PATH -m query --mouse)
mouse_x=$(echo "$mouse_loc" | $JQ_PATH -r '.x')
mouse_y=$(echo "$mouse_loc" | $JQ_PATH -r '.y')
mouse_display_info=$($YABAI_PATH -m query --displays | $JQ_PATH -r --argjson x "$mouse_x" --argjson y "$mouse_y" '.[] | select(.frame.x <= $x and .frame.y <= $y and .frame.x + .frame.w > $x and .frame.y + .frame.h > $y)' 2>/dev/null)

if [[ -z "$mouse_display_info" ]]; then
    # Fallback: Use the focused display if mouse display detection fails
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Could not determine display under mouse coordinates ($mouse_x, $mouse_y). Falling back to focused display."
    mouse_display_info=$($YABAI_PATH -m query --displays | $JQ_PATH '.[] | select(.has_focus == true)' 2>/dev/null)
    if [[ -z "$mouse_display_info" ]]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not determine focused display either. Aborting."
        exit 1
    fi
fi

mouse_display_index=$(echo "$mouse_display_info" | $JQ_PATH -r '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Target display index determined: $mouse_display_index"

# Focus the target display
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing display index $mouse_display_index."
"$YABAI_PATH" -m display --focus "$mouse_display_index"
focus_exit_code=$?

if [[ $focus_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Focusing display $mouse_display_index failed (Exit code: $focus_exit_code). Proceeding with space change attempt."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused display $mouse_display_index."
fi

# Change space on the now focused display
space_change_direction="unknown"
if [[ "$ACTION" == "left" ]]; then
    space_change_direction="prev"
elif [[ "$ACTION" == "right" ]]; then
    space_change_direction="next"
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Changing space on focused display ($mouse_display_index) direction: $space_change_direction"
"$YABAI_PATH" -m space --focus "$space_change_direction"
space_exit_code=$?

if [[ $space_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to change space (Exit code: $space_exit_code)."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully changed space."
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
final_exit_code=$([[ $focus_exit_code -ne 0 || $space_exit_code -ne 0 ]] && echo 1 || echo 0)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with overall exit code $final_exit_code (focus: $focus_exit_code, space: $space_exit_code)."

exit $final_exit_code 