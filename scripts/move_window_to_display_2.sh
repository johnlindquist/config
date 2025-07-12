#!/usr/bin/env bash
# ---------- move_window_to_display_2.sh ----------
# Moves the focused window to display index 2, then refocuses the window.

LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="move_window_to_display_2.sh"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

TARGET_DISPLAY_INDEX=2

log_state() {
  local type="$1"
  local window_id=$($YABAI_PATH -m query --windows --window | $JQ_PATH -r '.id' 2>/dev/null || echo "unknown")
  local current_display=$($YABAI_PATH -m query --windows --window | $JQ_PATH -r '.display' 2>/dev/null || echo "unknown")
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Current Display: $current_display, Target Display: $TARGET_DISPLAY_INDEX"
}

log_state "BEFORE_STATE"

window_id=$($YABAI_PATH -m query --windows --window | $JQ_PATH '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not retrieve focused window ID."
  exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to display $TARGET_DISPLAY_INDEX."
$YABAI_PATH -m window "$window_id" --display "$TARGET_DISPLAY_INDEX"
move_exit=$?
if [[ $move_exit -ne 0 ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to move window (Exit code: $move_exit)."
  exit 1
fi

$YABAI_PATH -m window --focus "$window_id"
focus_exit=$?
if [[ $focus_exit -ne 0 ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Failed to refocus window after move (Exit code: $focus_exit)."
fi

log_state "AFTER_STATE"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."
exit 0 