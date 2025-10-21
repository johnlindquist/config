#!/usr/bin/env bash
# ---------- space_right.sh ----------

# --- Script Setup ---
SCRIPT_NAME="space_right"
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

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying next space index"
next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index > $cur))            # only spaces to the right
        | sort_by(.index) | .[0].index // ""  # pick the closest, or ""')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Next space index: '$next'"

# Use literal string comparison for the jq fallback ""
if [[ "$next" == '""' ]]; then # Check if next IS literally ""
  # Edge -> check if last space is empty, if not create new space
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected (next is \"\"), checking if last space has windows"
  
  last=$($y -m query --spaces --display | $jq '.[-1].index')
  last_window_count=$($y -m query --spaces --display | $jq '.[-1].windows | length')
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Last space ($last) window count: $last_window_count"
  
  if [[ "$last_window_count" -gt 0 ]]; then
    # Last space has windows, create new space
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Last space has windows, creating new space"
    $y -m space --create
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Created new space"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying new last space index"
    last=$($y -m query --spaces --display | $jq '.[-1].index')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "New last space index: $last"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing last space ($last)"
    $y -m space --focus "$last"
  else
    # Last space is empty, just go there
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Last space is empty, focusing it"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing last space ($last)"
    $y -m space --focus "$last"
  fi
else # Next is NOT ""
  # Neighbour exists -> just hop
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Neighbour found ('$next'), focusing"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $next"
  $y -m space --focus "$next"
fi

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
