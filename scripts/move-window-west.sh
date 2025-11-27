#!/bin/bash

# Script to move the focused window to the previous "column" to the left
# by focusing west and then swapping with the new focused window ID.

# --- Script Setup ---
SCRIPT_NAME="move-window-west"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started - Move window to previous column (west)"

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

# Get focused window ID
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Getting focused window ID"
FOCUSED_WINDOW_ID=$($y -m query --windows --window | $jq -r '.id')

if [ -z "$FOCUSED_WINDOW_ID" ] || [ "$FOCUSED_WINDOW_ID" == "null" ]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No focused window found"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Initial focused window ID: $FOCUSED_WINDOW_ID"

# Attempt to focus the window to the west
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to focus window to the west"
$y -m window --focus west

# Check if focus changed
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Checking if focus changed"
NEW_FOCUSED_WINDOW_ID=$($y -m query --windows --window | $jq -r '.id')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window ID after attempting focus west: $NEW_FOCUSED_WINDOW_ID"

if [ "$FOCUSED_WINDOW_ID" == "$NEW_FOCUSED_WINDOW_ID" ]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focus did not change. Window might be the leftmost or focus failed"
  log_state "AFTER"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - no change needed"
  exit 0
fi

if [ -z "$NEW_FOCUSED_WINDOW_ID" ] || [ "$NEW_FOCUSED_WINDOW_ID" == "null" ]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to get new focused window ID after focus west"
  # Attempt to focus back - best effort
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to restore focus to original window"
  $y -m window "$FOCUSED_WINDOW_ID" --focus
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  exit 1
fi

# Swap the original window with the newly focused (western) window
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Swapping original window $FOCUSED_WINDOW_ID with western window $NEW_FOCUSED_WINDOW_ID"
$y -m window "$FOCUSED_WINDOW_ID" --swap "$NEW_FOCUSED_WINDOW_ID"

if [ $? -eq 0 ]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully swapped windows"
  # Focus back on the original window (which is now in the western position)
  # Small delay to ensure yabai has completed the swap
  sleep 0.1
  focus_window "$FOCUSED_WINDOW_ID"
else
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to swap windows $FOCUSED_WINDOW_ID and $NEW_FOCUSED_WINDOW_ID"
  # Attempt to focus back if swap failed
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to restore focus to original window"
  $y -m window "$FOCUSED_WINDOW_ID" --focus
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  exit 1
fi

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished successfully"
exit 0 