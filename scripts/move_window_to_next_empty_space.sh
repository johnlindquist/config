#!/usr/bin/env bash
# ---------- move_window_to_next_empty_space.sh ----------
# Moves the current window to the next empty space on the current display.
# If no empty space is found after the current one, it creates a new space.

# --- Script Setup ---
SCRIPT_NAME="move_window_to_next_empty_space"
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
  local current_window=$($y -m query --windows --window 2>/dev/null | $jq -r '."id"' 2>/dev/null || echo "null")
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
    echo "Error: No focused window found." >&2
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focused window ID: $window_id"

# 2. Get Current Space Index
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying current space index"
cur=$($y -m query --spaces --space | $jq '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space index: $cur"

# 3. Find the index of the next empty space on the current display
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Finding next empty space index"
next_empty=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
  map(select(.index > $cur and (.windows | length == 0))) # Filter spaces: index > current AND window count is 0
  | sort_by(.index) # Sort by index
  | .[0].index // "" # Get the index of the first one, or fallback to literal ""
')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Next empty space index: '$next_empty'"

# 4. Determine target space and move/focus
target_space=""
if [[ "$next_empty" == '""' ]]; then # Check if next_empty IS literally ""
  # No empty space found after current -> create new one
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No empty space found after current, creating new space"
  $y -m space --create
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Created new space"
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying last space index (the new one)"
  last=$($y -m query --spaces --display | $jq '.[-1].index')
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Last space index: $last"
  target_space="$last"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Target space set to: $target_space (newly created)"
else
  # Found an empty space
  target_space="$next_empty"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Target space set to: $target_space (existing empty space)"
  
  # Check windows on target space before moving
  local windows_on_target=$($y -m query --windows --space "$target_space" | $jq 'length')
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Number of windows on target space $target_space before move: $windows_on_target"
fi

# 5. Move window to target space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space $target_space"
$y -m window "$window_id" --space "$target_space"

# Check windows on target space after moving
local windows_on_target_after=$($y -m query --windows --space "$target_space" | $jq 'length')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Number of windows on target space $target_space after move: $windows_on_target_after"

# 6. Focus the target space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $target_space"
$y -m space --focus "$target_space"

# Check what window is focused after space change
local focused_after_space_change=$($y -m query --windows --window | $jq '.id')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focused window after space change: $focused_after_space_change"

# 7. Refocus the moved window
focus_window "$window_id"

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 