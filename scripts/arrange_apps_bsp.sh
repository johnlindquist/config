#!/bin/bash

# Script to arrange apps using BSP layout
SCRIPT_NAME="arrange_apps_bsp"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Arranging apps using BSP layout"

# Paths to required binaries
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Get current display 4 spaces
space_1=9
space_2=10

# Function to arrange two windows side by side on a space
arrange_space() {
    local space=$1
    local left_app=$2
    local right_app=$3
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Arranging $left_app and $right_app on space $space"
    
    # Get window IDs
    local left_window=$($YABAI -m query --windows | $JQ -r --arg app "$left_app" '.[] | select(.app == $app) | .id' | head -1)
    local right_window=$($YABAI -m query --windows | $JQ -r --arg app "$right_app" '.[] | select(.app == $app) | .id' | head -1)
    
    if [ -z "$left_window" ] || [ -z "$right_window" ]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Missing windows for $left_app or $right_app"
        return
    fi
    
    # Focus the space
    $YABAI -m space --focus "$space"
    sleep 0.2
    
    # Balance the space first
    $YABAI -m space --balance
    
    # Ensure both windows are on this space
    $YABAI -m window "$left_window" --space "$space"
    $YABAI -m window "$right_window" --space "$space"
    sleep 0.3
    
    # Set split type to vertical (side by side)
    $YABAI -m config --space "$space" split_type vertical
    
    # Focus left window and warp right window to the east
    $YABAI -m window --focus "$left_window"
    sleep 0.1
    $YABAI -m window "$right_window" --warp east
    
    # Balance the space again
    $YABAI -m space --balance
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Arranged $left_app (left) and $right_app (right) on space $space"
}

# Arrange Space 9: Pieces (left) and Zed (right)
arrange_space 9 "Pieces" "Zed"

# Arrange Space 10: Slack (left) and Messages (right)
arrange_space 10 "Slack" "Messages"

# Update yabairc with the correct space numbers
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Updating yabairc with correct space numbers"

# Update the yabairc file
sed -i '' 's/space=12/space=9/g' /Users/johnlindquist/.config/yabairc
sed -i '' 's/space=11/space=10/g' /Users/johnlindquist/.config/yabairc

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Configuration updated"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"

echo "Apps have been arranged in BSP layout:"
echo "  Space 9: Pieces (left), Zed (right)"
echo "  Space 10: Slack (left), Messages (right)"
echo ""
echo "Note: yabairc has been updated with the correct space numbers."