#!/bin/bash

# Script to adjust focused window to ensure borders are visible
SCRIPT_NAME="adjust_focused_window_for_border"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Paths to required binaries
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Border width (should match your borders setting)
BORDER_WIDTH=10

# Get current window info
WINDOW_INFO=$($YABAI -m query --windows --window 2>/dev/null)
if [ -z "$WINDOW_INFO" ]; then
    exit 0
fi

# Check if window is floating
IS_FLOATING=$(echo "$WINDOW_INFO" | $JQ -r '."is-floating"')
if [ "$IS_FLOATING" = "true" ]; then
    # Skip floating windows
    exit 0
fi

# Get display info
DISPLAY_INFO=$($YABAI -m query --displays --display 2>/dev/null)
if [ -z "$DISPLAY_INFO" ]; then
    exit 0
fi

# Get display frame
DISPLAY_X=$(echo "$DISPLAY_INFO" | $JQ -r '.frame.x')
DISPLAY_Y=$(echo "$DISPLAY_INFO" | $JQ -r '.frame.y')
DISPLAY_WIDTH=$(echo "$DISPLAY_INFO" | $JQ -r '.frame.w')
DISPLAY_HEIGHT=$(echo "$DISPLAY_INFO" | $JQ -r '.frame.h')

# Get current window frame
WINDOW_X=$(echo "$WINDOW_INFO" | $JQ -r '.frame.x')
WINDOW_Y=$(echo "$WINDOW_INFO" | $JQ -r '.frame.y')
WINDOW_WIDTH=$(echo "$WINDOW_INFO" | $JQ -r '.frame.w')
WINDOW_HEIGHT=$(echo "$WINDOW_INFO" | $JQ -r '.frame.h')
WINDOW_ID=$(echo "$WINDOW_INFO" | $JQ -r '.id')

# Check if window is at display edges
AT_TOP=$(echo "$WINDOW_Y <= $DISPLAY_Y + 5" | bc -l)
AT_BOTTOM=$(echo "$WINDOW_Y + $WINDOW_HEIGHT >= $DISPLAY_Y + $DISPLAY_HEIGHT - 5" | bc -l)
AT_LEFT=$(echo "$WINDOW_X <= $DISPLAY_X + 5" | bc -l)
AT_RIGHT=$(echo "$WINDOW_X + $WINDOW_WIDTH >= $DISPLAY_X + $DISPLAY_WIDTH - 5" | bc -l)

# Adjust window if at edges
if [ "$AT_TOP" = "1" ] || [ "$AT_BOTTOM" = "1" ] || [ "$AT_LEFT" = "1" ] || [ "$AT_RIGHT" = "1" ]; then
    # Calculate new position and size
    NEW_X=$WINDOW_X
    NEW_Y=$WINDOW_Y
    NEW_WIDTH=$WINDOW_WIDTH
    NEW_HEIGHT=$WINDOW_HEIGHT
    
    if [ "$AT_TOP" = "1" ]; then
        NEW_Y=$(echo "$DISPLAY_Y + $BORDER_WIDTH" | bc -l)
        NEW_HEIGHT=$(echo "$NEW_HEIGHT - $BORDER_WIDTH" | bc -l)
    fi
    
    if [ "$AT_BOTTOM" = "1" ]; then
        NEW_HEIGHT=$(echo "$DISPLAY_Y + $DISPLAY_HEIGHT - $NEW_Y - $BORDER_WIDTH" | bc -l)
    fi
    
    if [ "$AT_LEFT" = "1" ]; then
        NEW_X=$(echo "$DISPLAY_X + $BORDER_WIDTH" | bc -l)
        NEW_WIDTH=$(echo "$NEW_WIDTH - $BORDER_WIDTH" | bc -l)
    fi
    
    if [ "$AT_RIGHT" = "1" ]; then
        NEW_WIDTH=$(echo "$DISPLAY_X + $DISPLAY_WIDTH - $NEW_X - $BORDER_WIDTH" | bc -l)
    fi
    
    # Apply the adjustments
    $YABAI -m window $WINDOW_ID --move abs:$NEW_X:$NEW_Y
    $YABAI -m window $WINDOW_ID --resize abs:$NEW_WIDTH:$NEW_HEIGHT
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adjusted window $WINDOW_ID for border visibility"
fi