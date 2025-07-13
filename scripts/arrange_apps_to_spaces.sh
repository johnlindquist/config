#!/bin/bash

# Script to arrange existing windows according to yabai rules
SCRIPT_NAME="arrange_apps_to_spaces"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Arranging apps to their designated spaces"

# Paths to required binaries
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to move and position a window
move_and_position_window() {
    local app_name=$1
    local target_display=$2
    local target_space=$3
    local grid_position=$4
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Processing $app_name -> Display $target_display, Space $target_space"
    
    # Find all windows for this app
    local window_ids=$($YABAI -m query --windows | $JQ -r --arg app "$app_name" '.[] | select(.app == $app) | .id')
    
    if [ -z "$window_ids" ]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "No windows found for $app_name"
        return
    fi
    
    # Process first window only (main window)
    local window_id=$(echo "$window_ids" | head -1)
    
    # Move window to target space
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving $app_name (window $window_id) to space $target_space"
    $YABAI -m window "$window_id" --space "$target_space"
    
    # Wait a moment for the move to complete
    sleep 0.5
    
    # Apply grid position
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Positioning $app_name with grid $grid_position"
    $YABAI -m window "$window_id" --grid "$grid_position"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully arranged $app_name"
}

# First, ensure the spaces exist
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Checking if target spaces exist"

# Check if space 11 and 12 exist on display 4
space_11_exists=$($YABAI -m query --spaces | $JQ -r '.[] | select(.index == 11 and .display == 4) | .index')
space_12_exists=$($YABAI -m query --spaces | $JQ -r '.[] | select(.index == 12 and .display == 4) | .index')

if [ -z "$space_11_exists" ] || [ -z "$space_12_exists" ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Required spaces 11 or 12 on display 4 do not exist"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current spaces on display 4:"
    $YABAI -m query --spaces --display 4 | $JQ -r '.[] | "Space \(.index)"'
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - missing required spaces"
    exit 1
fi

# Arrange the apps
# Display 4, Space 12: Pieces (left) and Zed (right)
move_and_position_window "Pieces" 4 12 "1:2:0:0:1:1"
move_and_position_window "Zed" 4 12 "1:2:1:0:1:1"

# Display 4, Space 11: Slack (left) and Messages (right)
move_and_position_window "Slack" 4 11 "1:2:0:0:1:1"
move_and_position_window "Messages" 4 11 "1:2:1:0:1:1"

# Focus back to the current space
current_space=$($YABAI -m query --spaces --space | $JQ -r '.index')
$YABAI -m space --focus "$current_space"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "All apps have been arranged"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"