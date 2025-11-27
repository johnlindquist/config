#!/usr/bin/env bash
# ---------- move_window_to_display_1.sh ----------
# Moves the focused window to display index 1 (first display), then refocuses the window.

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="move_window_to_display_1.sh"

# Log script start 
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Logical grid slot we want: 1=top-left, 2=top-right, 3=bottom-left, 4=bottom-right
TARGET_GRID_SLOT=1

# Function to log state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local window_id=$($YABAI_PATH -m query --windows --window | $JQ_PATH -r '.id' 2>/dev/null || echo "unknown")
    local current_display=$($YABAI_PATH -m query --windows --window | $JQ_PATH -r '.display' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Current Display: $current_display, Target Grid Slot: $TARGET_GRID_SLOT"
}

# Source display mapping helper
DISPLAY_HELPER_PATH="$(dirname "$0")/display_mapping.sh"
if [[ -f "$DISPLAY_HELPER_PATH" ]]; then
  # shellcheck disable=SC1090
  . "$DISPLAY_HELPER_PATH"
fi

# Log state before action
log_state "BEFORE_STATE"

# --- Script Logic ---
window_id=$($YABAI_PATH -m query --windows --window | $JQ_PATH '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not retrieve focused window ID."
    exit 1
fi

target_display_index=$(get_display_index_for_grid_slot "$TARGET_GRID_SLOT")
if [[ -z "$target_display_index" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not resolve target display for grid slot $TARGET_GRID_SLOT. Ensure sufficient displays are connected."
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to grid slot $TARGET_GRID_SLOT (display index $target_display_index)."
$YABAI_PATH -m window "$window_id" --display "$target_display_index"
move_exit=$?

if [[ $move_exit -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to move window (Exit code: $move_exit)."
    exit 1
fi

# Refocus the window to ensure focus remains
$YABAI_PATH -m window --focus "$window_id"
focus_exit=$?

if [[ $focus_exit -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Failed to refocus window after move (Exit code: $focus_exit)."
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0 
