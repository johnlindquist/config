#!/bin/bash
# ---------- space_right_wrap.sh ----------
# Focuses the next space *with windows* on the display containing the focused window, wrapping around.

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="space_right_wrap.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

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
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Determining current space."

# Get current space index
current_space_index=$($YABAI_PATH -m query --spaces --space | $JQ_PATH '.index')
if ! [[ "$current_space_index" =~ ^[0-9]+$ ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get current space index. Aborting."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space index: $current_space_index"

# Get all spaces sorted by index
all_spaces_indices_sorted=$($YABAI_PATH -m query --spaces | $JQ_PATH '.[].index' | sort -n)

# Find the next space index globally
next_space_index=""
current_found=false
first_index=""
while IFS= read -r index; do
    if [[ -z "$first_index" ]]; then
        first_index="$index"
    fi
    if $current_found; then
        # This is the first index *after* current
        next_space_index="$index"
        break
    elif [[ "$index" == "$current_space_index" ]]; then
        current_found=true
        # Continue loop to find the next one, or wrap if this is the last
    fi
done <<< "$all_spaces_indices_sorted"

# Handle wrap-around case (current was the last space)
if $current_found && [[ -z "$next_space_index" ]]; then
    # If current was found but next is still empty, current must have been the last
    next_space_index="$first_index"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current space is the last globally ($current_space_index). Wrapping around to the first space ($next_space_index)."
elif ! $current_found; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not find current space index $current_space_index in the list of all spaces. Aborting."
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Target next space index (with wrap): $next_space_index"

# Focus the next space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space index $next_space_index."
$YABAI_PATH -m space --focus "$next_space_index"
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to focus space $next_space_index (Exit code: $exit_code)."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused space $next_space_index."
fi

# Log final state
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $exit_code."

exit $exit_code 