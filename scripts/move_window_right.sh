#!/usr/bin/env bash
# ---------- move_window_right.sh ----------
# Moves the current window to the next space, creating one if necessary.

# --- Script Setup ---
SCRIPT_NAME="move_window_right"
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

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying next space index"
next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index > $cur))            # only spaces to the right
        | sort_by(.index) | .[0].index // ""  # pick the closest, or ""')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Next space index: '$next'"

# Use literal string comparison for the jq fallback ""
if [[ "$next" == '""' ]]; then # Check if next IS literally ""
  # Edge -> create space, then move window
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected (next is \"\"), creating new space"
  $y -m space --create
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Created new space"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying last space index"
  last=$($y -m query --spaces --display | $jq '.[-1].index')
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Last space index: $last"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space $last"
  $y -m window "$window_id" --space "$last"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $last"
  $y -m space --focus "$last"
  
  # Small delay to ensure yabai has completed the space switch
  sleep 0.1
  
  focus_window "$window_id"
else # Next is NOT ""
  # Neighbour exists -> move window there
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Neighbour found ('$next'), moving window $window_id to space $next"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space $next"
  $y -m window "$window_id" --space "$next"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $next"
  $y -m space --focus "$next"
  
  # Small delay to ensure yabai has completed the space switch
  sleep 0.1
  
  focus_window "$window_id"
fi

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 