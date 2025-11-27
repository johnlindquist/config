#!/usr/bin/env bash
# ---------- move_window_right_half.sh ----------
# Resizes the focused window to the right half of the screen at full height.

# --- Script Setup ---
SCRIPT_NAME="move_window_right_half"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started - Resize window to right half"

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# --- Helper Functions ---
log_state() {
  local state_type=$1
  local current_window=$($y -m query --windows --window 2>/dev/null | $jq -r '.id' 2>/dev/null || echo "null")
  local current_space=$($y -m query --spaces --space 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "null")
  local current_display=$($y -m query --displays --display 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "null")
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "${state_type}_STATE" \
    "window:$current_window space:$current_space display:$current_display"
}

focus_window() {
  local window_id="$1"
  if [[ -n "$window_id" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Refocusing window $window_id"
    $y -m window --focus "$window_id"
    
    # Check what window is actually focused after the command
    local actual_focused=$($y -m query --windows --window | $jq '.id')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Actually focused window after refocus attempt: $actual_focused"
  fi
}

# Log before state
log_state "BEFORE"

# 1. Get Focused Window ID
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Getting focused window ID"
window_id=$($y -m query --windows --window | $jq '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get focused window ID"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focused window ID: $window_id"

# 2. Resize window to right half using grid (1 row, 2 cols, start at col 1, width 1, height 1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Resizing window $window_id to right half"
$y -m window --grid 1:2:1:0:1:1
if [[ $? -eq 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Grid resize command executed successfully"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Grid resize command failed"
fi

# 3. Refocus the window (good practice to ensure focus)
# Small delay to ensure yabai has completed the resize
sleep 0.1
focus_window "$window_id"

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 