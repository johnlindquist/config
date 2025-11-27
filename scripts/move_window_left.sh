#!/usr/bin/env bash
# ---------- move_window_left.sh ----------
# Moves the current window to the previous space, creating one if necessary.

# --- Script Setup ---
SCRIPT_NAME="move_window_left"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# --- Helper Functions ---
log_state() {
  local state_type=$1
  local current_window=$($y -m query --windows --window 2>/dev/null | $jq -r '"id"' 2>/dev/null || echo "null")
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

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Getting focused window ID"
window_id=$($y -m query --windows --window | $jq '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get focused window ID"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focused window ID: $window_id"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying current space index"
cur=$($y -m query --spaces --space | $jq '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space index: $cur"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying previous space index"
prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index < $cur))            # only spaces to the left
        | sort_by(.index) | .[-1].index // "" # pick the closest, or ""')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Previous space index: '$prev'"

# Use literal string comparison for the jq fallback ""
if [[ "$prev" == '""' ]]; then # Check if prev IS literally ""
  # Edge -> create space, move it to pos 1, then move window
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected (prev is \"\"), creating new space"
  $y -m space --create
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Created new space"
  
  # Need to focus the new space briefly to move it
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying last space index (which is the new one)"
  new=$($y -m query --spaces --display | $jq '.[-1].index')
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "New space index: $new"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing new space ($new) temporarily"
  $y -m space --focus "$new"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving new space ($new) to position 1"
  $y -m space --move 1
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space 1"
  $y -m window "$window_id" --space 1
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space 1"
  $y -m space --focus 1
  
  # Small delay to ensure yabai has completed the space switch
  sleep 0.1
  
  focus_window "$window_id"
else # Prev is NOT ""
  # Neighbour exists -> move window there
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Neighbour found ('$prev'), moving window $window_id to space $prev"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space $prev"
  $y -m window "$window_id" --space "$prev"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $prev"
  $y -m space --focus "$prev"
  
  # Small delay to ensure yabai has completed the space switch
  sleep 0.1
  
  focus_window "$window_id"
fi

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 