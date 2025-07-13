#!/bin/bash

# Script to create spaces and arrange apps
SCRIPT_NAME="setup_app_spaces_and_arrange"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Setting up spaces and arranging apps"

# Paths to required binaries
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# First, let's create a second space on display 4 for our apps
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Creating additional space on display 4"

# Focus display 4
$YABAI -m display --focus 4

# Create a new space on the current display
$YABAI -m space --create

# Get the spaces on display 4
display_4_spaces=$($YABAI -m query --spaces --display 4 | $JQ -r '.[].index' | sort -n)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Spaces on display 4: $display_4_spaces"

# Use the first two spaces on display 4
space_1=$(echo "$display_4_spaces" | head -1)
space_2=$(echo "$display_4_spaces" | tail -1)

if [ "$space_1" = "$space_2" ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to create second space on display 4"
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Using spaces $space_1 and $space_2 on display 4"

# Function to move and position a window
arrange_window() {
    local app_name=$1
    local target_space=$2
    local grid_position=$3
    
    # Find the window for this app
    local window_id=$($YABAI -m query --windows | $JQ -r --arg app "$app_name" '.[] | select(.app == $app) | .id' | head -1)
    
    if [ -z "$window_id" ]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "No window found for $app_name"
        return
    fi
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving $app_name (window $window_id) to space $target_space with grid $grid_position"
    
    # Move to space
    $YABAI -m window "$window_id" --space "$target_space"
    
    # Wait for move to complete
    sleep 0.2
    
    # Apply grid position
    $YABAI -m window "$window_id" --grid "$grid_position"
}

# Arrange apps on first space (Pieces left, Zed right)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Arranging Pieces and Zed on space $space_1"
arrange_window "Pieces" "$space_1" "1:2:0:0:1:1"
arrange_window "Zed" "$space_1" "1:2:1:0:1:1"

# Arrange apps on second space (Slack left, Messages right)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Arranging Slack and Messages on space $space_2"
arrange_window "Slack" "$space_2" "1:2:0:0:1:1"
arrange_window "Messages" "$space_2" "1:2:1:0:1:1"

# Update yabai rules to use the actual space numbers
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Updating yabai rules with correct space numbers"

# Remove old rules
$YABAI -m rule --remove "Pieces" 2>/dev/null || true
$YABAI -m rule --remove "Zed" 2>/dev/null || true
$YABAI -m rule --remove "Slack" 2>/dev/null || true
$YABAI -m rule --remove "Messages" 2>/dev/null || true

# Add new rules with correct space numbers
$YABAI -m rule --add app="^Pieces$" display=4 space="$space_1" manage=on grid=1:2:0:0:1:1
$YABAI -m rule --add app="^Zed$" display=4 space="$space_1" manage=on grid=1:2:1:0:1:1
$YABAI -m rule --add app="^Slack$" display=4 space="$space_2" manage=on grid=1:2:0:0:1:1
$YABAI -m rule --add app="^Messages$" display=4 space="$space_2" manage=on grid=1:2:1:0:1:1

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Apps arranged successfully"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"

echo "Apps have been arranged:"
echo "  Space $space_1: Pieces (left), Zed (right)"
echo "  Space $space_2: Slack (left), Messages (right)"