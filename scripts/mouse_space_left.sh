#!/usr/bin/env bash

# Focuses the previous space on the display where the mouse pointer is located.

# --- Script Setup ---
SCRIPT_NAME="mouse_space_left"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# --- Configuration ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"
CLICLICK_PATH="/opt/homebrew/bin/cliclick"

# --- Helper Functions ---
log_state() {
  local state_type=$1
  local current_space=$($YABAI_PATH -m query --spaces --space 2>/dev/null | $JQ_PATH -r '.index' 2>/dev/null || echo "null")
  local current_display=$($YABAI_PATH -m query --displays --display 2>/dev/null | $JQ_PATH -r '.index' 2>/dev/null || echo "null")
  local mouse_coords=$("$CLICLICK_PATH" q:. 2>/dev/null || echo "null,null")
  
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "${state_type}_STATE" \
    "space:$current_space display:$current_display mouse:$mouse_coords"
}

# Log before state
log_state "BEFORE"

# Check for required commands
if ! command -v "$YABAI_PATH" &> /dev/null; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "yabai not found at $YABAI_PATH"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  echo "Error: yabai not found at $YABAI_PATH" >&2
  exit 1
fi
if ! command -v "$JQ_PATH" &> /dev/null; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "jq not found at $JQ_PATH"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  echo "Error: jq not found at $JQ_PATH" >&2
  exit 1
fi
if ! command -v "$CLICLICK_PATH" &> /dev/null; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "cliclick not found at $CLICLICK_PATH. Please install (brew install cliclick)"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  echo "Error: cliclick not found at $CLICLICK_PATH. Please install (brew install cliclick)." >&2
  exit 1
fi

# --- Core Logic ---

# 1. Get Mouse Coordinates
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Getting mouse coordinates"
coords=$("$CLICLICK_PATH" q:.) # Query format: x,y
if [[ ! "$coords" =~ ^[0-9]+\.?[0-9]*,[0-9]+\.?[0-9]*$ ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to get valid mouse coordinates from cliclick. Output: $coords"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    echo "Error: Failed to get mouse coordinates." >&2
    exit 1
fi
mouse_x=$(echo "$coords" | cut -d',' -f1 | cut -d'.' -f1) # Use integer part
mouse_y=$(echo "$coords" | cut -d',' -f2 | cut -d'.' -f1) # Use integer part
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mouse coordinates: X=$mouse_x, Y=$mouse_y"

# 2. Get Display Info and Find Target Display
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying display information"
displays_json=$("$YABAI_PATH" -m query --displays)
if [[ -z "$displays_json" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to query displays using yabai"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    echo "Error: Could not query displays." >&2
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Raw display JSON: $displays_json"

# Use jq to find the display containing the mouse coordinates
target_display_id=$("$JQ_PATH" --argjson mx "$mouse_x" --argjson my "$mouse_y" -r '
  map(select(
    .frame.x <= $mx and $mx < (.frame.x + .frame.w) and
    .frame.y <= $my and $my < (.frame.y + .frame.h)
  )) | .[0].id // empty
' <<< "$displays_json")

if [[ -z "$target_display_id" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not determine display for mouse coordinates ($mouse_x, $mouse_y)"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Available displays: $displays_json"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  echo "Error: Could not determine which display the mouse is on." >&2
  exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mouse is on display ID: $target_display_id"

# 3. Find Current Visible Space and All Spaces on Target Display
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying spaces for display $target_display_id"
spaces_on_display_json=$("$YABAI_PATH" -m query --spaces --display "$target_display_id")
if [[ -z "$spaces_on_display_json" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to query spaces for display $target_display_id"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    echo "Error: Could not query spaces for the target display." >&2
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Spaces on target display JSON: $spaces_on_display_json"

# Find the index of the currently visible space on the target display
current_visible_index=$("$JQ_PATH" -r '.[] | select(."is-visible" == true) | .index // empty' <<< "$spaces_on_display_json")

if [[ -z "$current_visible_index" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Could not find a visible space on display $target_display_id"
    # Fallback: use the first space on the display?
    current_visible_index=$("$JQ_PATH" -r 'sort_by(.index) | .[0].index // empty' <<< "$spaces_on_display_json")
    if [[ -z "$current_visible_index" ]]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Fallback failed. No spaces found on display $target_display_id"
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
        echo "Error: No spaces found on the target display." >&2
        exit 1
    fi
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Fallback: Using first space index $current_visible_index as current"
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current visible space index on display $target_display_id: $current_visible_index"

# 4. Determine the Previous Space Index
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Calculating previous space index relative to $current_visible_index"
previous_space_index=$("$JQ_PATH" --argjson current_idx "$current_visible_index" -r '
  sort_by(.index) | # Ensure spaces are sorted by index
  # Find the last space with index < current_idx
  (map(select(.index < $current_idx)) | .[-1].index // null) as $prev_idx |
  # If no previous index found (current is first), wrap around to the last space
  ($prev_idx // (map(select(.index != $current_idx)) | sort_by(.index) | .[-1].index // null)) as $final_prev |
  # If still null (only one space?), return empty to avoid action
  ($final_prev // empty)
' <<< "$spaces_on_display_json")

if [[ -z "$previous_space_index" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Could not determine the previous space index. This might mean there is only one space on display $target_display_id"
  # Check if there really is only one space
  space_count=$("$JQ_PATH" 'length' <<< "$spaces_on_display_json")
  if [[ "$space_count" -le 1 ]]; then
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Confirmed: Only one space ($space_count) exists on display $target_display_id. No action needed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished (single space on display)"
      echo "Only one space on this display." # User-friendly message
      exit 0
  else
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to determine previous space index, but multiple spaces ($space_count) exist. Logic error?"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
      echo "Error: Could not determine the previous space." >&2
      exit 1
  fi
fi

# Avoid focusing the same space if logic somehow resulted in it (shouldn't happen with the jq logic)
if [[ "$previous_space_index" == "$current_visible_index" ]]; then
     "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Previous space index ($previous_space_index) is the same as current ($current_visible_index). No action needed"
     "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished (already on target space)"
     exit 0
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Determined previous space index on display $target_display_id: $previous_space_index"

# 5. Focus the Previous Space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space index $previous_space_index"
if "$YABAI_PATH" -m space --focus "$previous_space_index"; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focus command executed successfully"
else
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "yabai focus command failed for index $previous_space_index"
  # Attempt to query the space to see if it exists
  space_info=$("$YABAI_PATH" -m query --spaces --space "$previous_space_index")
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Queried space info for index $previous_space_index: $space_info"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
  echo "Error: Failed to focus space $previous_space_index." >&2
  exit 1
fi

# Log after state
log_state "AFTER"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
exit 0 