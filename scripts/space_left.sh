#!/usr/bin/env bash
# ---------- space_left.sh ----------

# --- Script Setup ---
SCRIPT_NAME="space_left"
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
  local current_space=$($y -m query --spaces --space 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "null")
  local current_display=$($y -m query --displays --display 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "null")
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "${state_type}_STATE" \
    "space:$current_space display:$current_display"
}

# Log before state
log_state "BEFORE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying current space index"
cur=$($y -m query --spaces --space   | $jq '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space index: $cur"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying previous space index"
prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index < $cur))            # only spaces to the left
        | sort_by(.index) | .[-1].index // "" # pick the closest, or ""')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Previous space index: '$prev'"

# Use literal string comparison for the jq fallback ""
if [[ "$prev" == '""' ]]; then # Check if prev IS literally ""
  # Edge -> check if space 1 is empty, if not create new space
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected (prev is \"\"), checking if space 1 has windows"
  
  space_1_window_count=$($y -m query --spaces --display | $jq 'map(select(.index == 1)) | .[0].windows | length')
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Space 1 window count: $space_1_window_count"
  
  if [[ "$space_1_window_count" -gt 0 ]]; then
    # Space 1 has windows, create new space
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Space 1 has windows, creating new space"
    $y -m space --create
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Created new space"
    
    # Note: focusing 'last' then moving to 1 is necessary
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying last space index (which is the new one)"
    new=$($y -m query --spaces --display | $jq '.[-1].index') 
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "New space index: $new"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing new space ($new)"
    $y -m space --focus "$new" # Focus temporarily to allow move
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving new space ($new) to position 1"
    $y -m space --move 1
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space 1"
    $y -m space --focus 1
  else
    # Space 1 is empty, just stay here
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Space 1 is empty, staying at current space"
  fi
else # Prev is NOT ""
  # Neighbour exists -> just hop
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Neighbour found ('$prev'), focusing"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $prev"
  $y -m space --focus "$prev"
fi

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
