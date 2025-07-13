#!/bin/bash

# Improved script to remove empty spaces
# Handles hidden windows and system apps better

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="remove_empty_spaces_improved.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Function to log state (Spaces and Windows)
log_state() {
    local type="$1"
    local spaces_info=$($YABAI_PATH -m query --spaces | $JQ_PATH -c '.' 2>/dev/null || echo "failed query spaces")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Spaces summary: $(echo "$spaces_info" | $JQ_PATH -r 'map({index, display, window_count: (.windows | length), first_window: ."first-window"})')"
}

# Function to check if a space has visible windows
space_has_visible_windows() {
    local space_index=$1
    local windows_json=$2
    
    # Get windows on this space
    local space_windows=$($JQ_PATH -n --argjson spaces "$all_spaces_json" --argjson idx "$space_index" \
        '[$spaces[] | select(.index == $idx) | .windows[]] | @csv' | tr -d '"')
    
    if [[ -z "$space_windows" ]]; then
        echo "false"
        return
    fi
    
    # Check if any window on this space is visible and meaningful
    local has_visible="false"
    IFS=',' read -ra window_ids <<< "$space_windows"
    
    for window_id in "${window_ids[@]}"; do
        local window_info=$(echo "$windows_json" | $JQ_PATH -r \
            --argjson wid "$window_id" \
            '.[] | select(.id == $wid) | {app, "is-visible", "is-hidden", role, "can-move"}')
        
        if [[ -n "$window_info" ]]; then
            local app=$(echo "$window_info" | $JQ_PATH -r '.app')
            local is_visible=$(echo "$window_info" | $JQ_PATH -r '."is-visible"')
            local is_hidden=$(echo "$window_info" | $JQ_PATH -r '."is-hidden"')
            local role=$(echo "$window_info" | $JQ_PATH -r '.role')
            local can_move=$(echo "$window_info" | $JQ_PATH -r '."can-move"')
            
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Space $space_index has window $window_id: app=$app, visible=$is_visible, hidden=$is_hidden, role=$role, can_move=$can_move"
            
            # Skip system windows with no role that can't be moved
            if [[ "$role" == "null" || "$role" == "" ]] && [[ "$can_move" == "false" ]]; then
                "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Ignoring system window: $app (id: $window_id)"
                continue
            fi
            
            # If any window is not hidden and has a proper role, space is not empty
            if [[ "$is_hidden" != "true" ]] && [[ "$role" != "null" && "$role" != "" ]]; then
                has_visible="true"
                break
            fi
        fi
    done
    
    echo "$has_visible"
}

# Log initial state
log_state "BEFORE_STATE"

# --- Script Logic ---
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Identifying truly empty spaces (excluding the currently focused space)."

# Get all spaces, windows, and focused space
all_spaces_json=$($YABAI_PATH -m query --spaces)
all_windows_json=$($YABAI_PATH -m query --windows)
focused_space_index=$($YABAI_PATH -m query --spaces --space | $JQ_PATH '.index')

# Find spaces that are truly empty (no visible windows)
empty_space_indices=""
all_space_indices=$(echo "$all_spaces_json" | $JQ_PATH -r '.[].index')

for space_index in $all_space_indices; do
    # Skip focused space
    if [[ "$space_index" == "$focused_space_index" ]]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Skipping focused space $space_index"
        continue
    fi
    
    # Check if space has visible windows
    has_visible=$(space_has_visible_windows "$space_index" "$all_windows_json")
    
    if [[ "$has_visible" == "false" ]]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Space $space_index appears empty (no visible windows)"
        empty_space_indices="$empty_space_indices $space_index"
    else
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Space $space_index has visible windows"
    fi
done

# Trim whitespace
empty_space_indices=$(echo "$empty_space_indices" | xargs)

# Sort indices in descending order to prevent index shifts
if [[ -n "$empty_space_indices" ]]; then
    empty_space_indices_sorted=$(echo "$empty_space_indices" | tr ' ' '\n' | sort -nr | tr '\n' ' ')
else
    empty_space_indices_sorted=""
fi

# Check if we found any empty spaces
if [[ -z "$empty_space_indices_sorted" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No truly empty spaces found (excluding the focused one). Nothing to do."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Found empty spaces to destroy (indices, descending): $empty_space_indices_sorted"
    
    # Use arrays to properly track counters
    destroyed_spaces=()
    failed_spaces=()
    
    # Loop through empty space indices and destroy them
    for space_index in $empty_space_indices_sorted; do
        # Basic check if space_index is a number
        if ! [[ "$space_index" =~ ^[0-9]+$ ]]; then
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Skipping invalid space index found: '$space_index'."
            continue
        fi
        
        # Check if it's the last space on its display
        space_display=$($YABAI_PATH -m query --spaces --space "$space_index" | $JQ_PATH '.display' 2>/dev/null)
        if [[ -z "$space_display" ]]; then
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Space $space_index no longer exists, skipping."
            continue
        fi
        
        spaces_on_display_count=$($YABAI_PATH -m query --spaces --display "$space_display" | $JQ_PATH 'length')
        
        if [[ "$spaces_on_display_count" -le 1 ]]; then
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Skipping space $space_index as it is the last one on display $space_display."
        else
            "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Destroying empty space index: $space_index"
            
            # Capture the actual output and exit code
            destroy_output=$($YABAI_PATH -m space "$space_index" --destroy 2>&1)
            exit_code=$?
            
            if [[ $exit_code -ne 0 ]]; then
                "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to destroy space $space_index (Exit code: $exit_code, Output: $destroy_output)"
                failed_spaces+=("$space_index")
            else
                "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully destroyed space $space_index"
                destroyed_spaces+=("$space_index")
            fi
        fi
    done
    
    # Report results
    total_destroyed=${#destroyed_spaces[@]}
    total_errors=${#failed_spaces[@]}
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "RESULT" "Finished processing empty spaces. Destroyed: $total_destroyed (${destroyed_spaces[*]}), Errors: $total_errors (${failed_spaces[*]})"
fi

# Log final state
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished."

exit 0