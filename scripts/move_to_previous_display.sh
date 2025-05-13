#!/bin/bash
# ---------- move_to_previous_display.sh ----------
# Moves the focused window to the previous display index, wrapping around, and refocuses it.

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="move_to_previous_display.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/move_to_previous_display.log

# --- Logging Setup ---
if [[ "$DEBUG" == "true" ]]; then
  LOG_FILE="$HOME/.config/logs/move_to_previous_display.log"
  # Create log dir if it doesn't exist
  mkdir -p "$(dirname "$LOG_FILE")"
  exec >> "$LOG_FILE" 2>&1
  echo "--- $(date) ---"
  echo "Starting move_to_previous_display.sh (DEBUG enabled)"
fi

log() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "$@"
  fi
}

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Function to log state
log_state() {
    local type="$1" # BEFORE_STATE or AFTER_STATE
    local window_id=$($YABAI_PATH -m query --windows --window | $JQ_PATH -r '.id' 2>/dev/null || echo "unknown")
    local space_id=$($YABAI_PATH -m query --spaces --space | $JQ_PATH -r '.index' 2>/dev/null || echo "unknown")
    local display_id=$($YABAI_PATH -m query --displays --display | $JQ_PATH -r '.index' 2>/dev/null || echo "unknown")
    local all_displays=$($YABAI_PATH -m query --displays | $JQ_PATH -c '.' 2>/dev/null || echo "failed to query displays")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Current Space: $space_id, Current Display: $display_id, All Displays: $all_displays"
}

# Log state before action
log_state "BEFORE_STATE"

# --- Script Logic ---
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Getting focused window and display details."

window_id=$($YABAI_PATH -m query --windows --window | $JQ_PATH '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get focused window ID."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focused window ID: $window_id"

current_display_index=$($YABAI_PATH -m query --windows --window "$window_id" | $JQ_PATH '.display')
if [[ -z "$current_display_index" || "$current_display_index" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get display index for window $window_id."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current display index: $current_display_index"

# Read sorted indices into a bash array
display_indices=()
while IFS= read -r line;
do
    display_indices+=("$line")
done < <($YABAI_PATH -m query --displays | $JQ_PATH '.[].index' | sort -n)

if [[ ${#display_indices[@]} -eq 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get display indices."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Available display indices: ${display_indices[*]}"

# Find the position of the current index in the sorted list
current_pos=-1
for i in "${!display_indices[@]}"; do
   if [[ "${display_indices[$i]}" == "$current_display_index" ]]; then
       current_pos=$i
       break
   fi
done

if [[ "$current_pos" -eq -1 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Current display index $current_display_index not found in the list of displays."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current index position in list: $current_pos"

# Calculate the previous position, wrapping around
num_displays=${#display_indices[@]}
prev_pos=$(( (current_pos - 1 + num_displays) % num_displays ))
prev_display_index=${display_indices[$prev_pos]}
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Calculated previous display index: $prev_display_index. Attempting move."

# Move and focus
$YABAI_PATH -m window "$window_id" --display "$prev_display_index"
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Yabai move window command failed (Exit code: $exit_code)."
else
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Move command executed successfully."
  $YABAI_PATH -m window --focus "$window_id"
  focus_exit_code=$?
  if [[ $focus_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Yabai focus window command failed after move (Exit code: $focus_exit_code)."
  else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Refocus command executed successfully."
  fi
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
final_exit_code=$([[ $exit_code -ne 0 || $focus_exit_code -ne 0 ]] && echo 1 || echo 0)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $final_exit_code."

exit $final_exit_code 