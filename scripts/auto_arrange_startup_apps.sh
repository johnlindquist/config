#!/bin/bash

# Script to auto-arrange specific apps on yabai startup
# This ensures existing windows are placed correctly even after restart

SCRIPT_NAME="auto_arrange_startup_apps"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Auto-arranging startup apps"

# Paths
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Wait a moment for yabai to fully initialize
sleep 2

# Function to move window to specific space and position
arrange_app() {
    local app_name=$1
    local target_space=$2
    local position=$3  # "left" or "right"
    
    # Find window for this app
    local window_id=$($YABAI -m query --windows | $JQ -r --arg app "$app_name" \
        '.[] | select(.app == $app) | .id' | head -1)
    
    if [ -z "$window_id" ]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "$app_name not found, skipping"
        return
    fi
    
    # Check if window is already on correct space
    local current_space=$($YABAI -m query --windows --window "$window_id" | $JQ -r '.space')
    
    if [ "$current_space" != "$target_space" ]; then
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving $app_name to space $target_space"
        $YABAI -m window "$window_id" --space "$target_space"
        sleep 0.2
    fi
    
    # Ensure proper positioning on the space
    # First, focus the space to work with it
    local current_focused_space=$($YABAI -m query --spaces --space | $JQ -r '.index')
    $YABAI -m space --focus "$target_space"
    sleep 0.1
    
    # Get all windows on this space
    local space_windows=$($YABAI -m query --windows --space "$target_space" | $JQ -r \
        '.[] | select(.["is-visible"] == true) | .id')
    local window_count=$(echo "$space_windows" | wc -l | tr -d ' ')
    
    if [ "$window_count" -eq 2 ]; then
        # Two windows - arrange them properly
        local other_window=$(echo "$space_windows" | grep -v "$window_id" | head -1)
        
        if [ "$position" = "left" ]; then
            # Make sure our app is on the left
            $YABAI -m window --focus "$window_id"
            $YABAI -m window "$other_window" --warp east 2>/dev/null || \
                $YABAI -m window "$other_window" --swap east 2>/dev/null || true
        else
            # Make sure our app is on the right
            $YABAI -m window --focus "$other_window"
            $YABAI -m window "$window_id" --warp east 2>/dev/null || \
                $YABAI -m window "$window_id" --swap east 2>/dev/null || true
        fi
        
        # Balance the space
        $YABAI -m space --balance
    fi
    
    # Return focus to original space
    $YABAI -m space --focus "$current_focused_space"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Arranged $app_name on space $target_space ($position)"
}

# Check if the expected spaces exist
space_9_exists=$($YABAI -m query --spaces | $JQ -r '.[] | select(.index == 9 and .display == 4) | .index')
space_10_exists=$($YABAI -m query --spaces | $JQ -r '.[] | select(.index == 10 and .display == 4) | .index')

if [ -n "$space_9_exists" ] && [ -n "$space_10_exists" ]; then
    # Arrange apps on Space 9: Pieces (left) and Zed (right)
    arrange_app "Pieces" 9 "left"
    arrange_app "Zed" 9 "right"
    
    # Arrange apps on Space 10: Slack (left) and Messages (right)
    arrange_app "Slack" 10 "left"
    arrange_app "Messages" 10 "right"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "Required spaces 9 and 10 on display 4 do not exist"
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Auto-arrange completed"