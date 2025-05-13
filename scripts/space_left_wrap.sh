#!/bin/bash
# ---------- space_left_wrap.sh ----------
# Focuses the previous space *with windows* on the display containing the focused window, wrapping around.

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="space_left_wrap.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/space_left_wrap.log

# --- Logging Setup ---
if [[ "$DEBUG" == "true" ]]; then
  LOG_FILE="$HOME/.config/logs/space_left_wrap.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  exec >> "$LOG_FILE" 2>&1
  echo "--- $(date) ---"
  echo "Starting space_left_wrap.sh (DEBUG enabled)"
fi

log() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "$@"
  fi
}

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Function to log state (Spaces, Displays, Focus)
log_state() {
    local type="$1"
    local focused_space_info=$($YABAI_PATH -m query --spaces --space | $JQ_PATH -c '.' 2>/dev/null || echo "failed query focused space")
    local focused_display_info=$($YABAI_PATH -m query --displays --display | $JQ_PATH -c '.' 2>/dev/null || echo "failed query focused display")
    local all_spaces_info=$($YABAI_PATH -m query --spaces | $JQ_PATH -c '.' 2>/dev/null || echo "failed query all spaces")
    local all_displays_info=$($YABAI_PATH -m query --displays | $JQ_PATH -c '.' 2>/dev/null || echo "failed query all displays")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Focused Space: $focused_space_info, Focused Display: $focused_display_info, All Spaces: $all_spaces_info, All Displays: $all_displays_info"
}

# Log initial state
log_state "BEFORE_STATE"

# --- Script Logic ---
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Determining current space and display."

# Get current space index
current_space_index=$($YABAI_PATH -m query --spaces --space | $JQ_PATH '.index')
if ! [[ "$current_space_index" =~ ^[0-9]+$ ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get current space index. Aborting."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space index: $current_space_index"

# Get current display index
current_display_index=$($YABAI_PATH -m query --displays --display | $JQ_PATH '.index')
if ! [[ "$current_display_index" =~ ^[0-9]+$ ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get current display index. Aborting."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current display index: $current_display_index"

# Get all spaces sorted by index
all_spaces_indices_sorted=$($YABAI_PATH -m query --spaces | $JQ_PATH '.[].index' | sort -n)

# Find the previous space index globally
prev_space_index=""
current_found=false
last_index=""
first_index=""
while IFS= read -r index; do
    if [[ -z "$first_index" ]]; then
        first_index="$index"
    fi
    if $current_found; then
        # This should not happen if we loop correctly, but safety first
        : # We already found current, looking for prev
    elif [[ "$index" == "$current_space_index" ]]; then
        current_found=true
        # If current is the first, wrap around to last
        if [[ -z "$prev_space_index" ]]; then
            # Need to continue loop to find the actual last index
            : 
        else 
            # Found the one immediately before current
            break
        fi
    else
        prev_space_index="$index"
    fi
    last_index="$index" # Keep track of the last index for wrap-around
done <<< "$all_spaces_indices_sorted"

# Handle wrap-around case (current was the first space)
if $current_found && [[ -z "$prev_space_index" ]]; then
    # We check if current_found is true AND prev_space_index is still empty
    # This means current was the first in the sorted list
    if [[ "$current_space_index" == "$first_index" ]]; then
       prev_space_index="$last_index"
       "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space is the first globally ($current_space_index). Wrapping around to the last space ($prev_space_index)."
    else 
       # This case shouldn't happen with the logic, but log if it does
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Logic error: Current found ($current_space_index) but prev is empty, and current is not first ($first_index). Using last index ($last_index) as fallback."
        prev_space_index="$last_index"
    fi
elif ! $current_found; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not find current space index $current_space_index in the list of all spaces. Aborting."
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Target previous space index (with wrap): $prev_space_index"

# Focus the previous space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space index $prev_space_index."
$YABAI_PATH -m space --focus "$prev_space_index"
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to focus space $prev_space_index (Exit code: $exit_code)."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused space $prev_space_index."
fi

# Log final state
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $exit_code."

exit $exit_code 