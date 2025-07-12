#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="remove_empty_spaces.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Function to log state (Spaces and Windows)
log_state() {
    local type="$1"
    local spaces_info=$($YABAI_PATH -m query --spaces | $JQ_PATH -c '.' 2>/dev/null || echo "failed query spaces")
    local windows_info=$($YABAI_PATH -m query --windows | $JQ_PATH -c '.' 2>/dev/null || echo "failed query windows")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Spaces: $spaces_info, Windows: $windows_info"
}

# Log initial state
log_state "BEFORE_STATE"

# --- Script Logic ---
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Identifying empty spaces (excluding the currently focused space)."

# Get all spaces and windows
all_spaces_json=$($YABAI_PATH -m query --spaces)
focused_space_index=$($YABAI_PATH -m query --spaces --space | $JQ_PATH '.index')

# Find spaces whose first-window == 0 (no real windows) excluding focused space
empty_space_indices=$($JQ_PATH -n --argjson spaces "$all_spaces_json" --argjson focused_idx "$focused_space_index" '
  [$spaces[] | select(.index != ($focused_idx | tonumber) and ."first-window" == 0) | .index] | .[]
')

# Sort indices in descending order to prevent Mission Control index shifts during deletion
empty_space_indices_sorted=$(echo "$empty_space_indices" | sort -nr)

# Check if we found any empty spaces
if [[ -z "$empty_space_indices_sorted" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No empty spaces found (excluding the focused one). Nothing to do."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Found empty spaces to destroy (indices, descending): $empty_space_indices_sorted"
    total_destroyed=0
    total_errors=0

    # Loop through empty space indices and destroy them
    echo "$empty_space_indices_sorted" | while IFS= read -r space_index; do
        # Basic check if space_index is a number
        if ! [[ "$space_index" =~ ^[0-9]+$ ]]; then
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Skipping invalid space index found: '$space_index'."
            continue
        fi

        # Check if it's the last space on its display - Yabai prevents this
        space_display=$($YABAI_PATH -m query --spaces --space "$space_index" | $JQ_PATH '.display')
        spaces_on_display_count=$($YABAI_PATH -m query --spaces --display "$space_display" | $JQ_PATH 'length')

        if [[ "$spaces_on_display_count" -le 1 ]]; then
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Skipping space $space_index as it is the last one on display $space_display."
        else
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Destroying empty space index: $space_index"
            $YABAI_PATH -m space "$space_index" --destroy
            exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to destroy space $space_index (Exit code: $exit_code)."
                ((total_errors++))
            else
                "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully destroyed space $space_index."
                ((total_destroyed++))
            fi
        fi
    done
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "RESULT" "Finished processing empty spaces. Destroyed: $total_destroyed, Errors: $total_errors."
fi

# Log final state
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0 # Exit successfully even if some destroys failed 