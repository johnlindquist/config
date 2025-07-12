#!/bin/bash

# Script to focus window in specified direction with cross-display support
# Usage: ./focus_direction.sh [east|west|north|south]

DIRECTION=$1
SCRIPT_NAME="focus_direction"

# Validate argument
if [ -z "$DIRECTION" ]; then
    echo "Usage: $0 [east|west|north|south]"
    exit 1
fi

case "$DIRECTION" in
    east|west|north|south)
        # Valid direction
        ;;
    *)
        echo "Invalid direction: $DIRECTION"
        echo "Usage: $0 [east|west|north|south]"
        exit 1
        ;;
esac

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started for direction: $DIRECTION"

# Paths to required binaries
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state
log_state() {
    local state_type=$1
    local current_window=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r '."id"' 2>/dev/null || echo "null")
    local current_space=$($YABAI -m query --spaces --space 2>/dev/null | $JQ -r '.index' 2>/dev/null || echo "null")
    local current_display=$($YABAI -m query --displays --display 2>/dev/null | $JQ -r '.index' 2>/dev/null || echo "null")
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "${state_type}_STATE" \
        "direction:$DIRECTION window:$current_window space:$current_space display:$current_display"
}

# Log before state
log_state "BEFORE"

# Try native yabai focus first
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting native focus $DIRECTION"

if $YABAI -m window --focus "$DIRECTION" 2>/dev/null; then
    # Log after state
    log_state "AFTER"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused window to the $DIRECTION (same display)"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
    exit 0
fi

# If native focus failed, try cross-display focus
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No window to the $DIRECTION on current display, checking adjacent displays"

# Get current display info
CURRENT_DISPLAY_INFO=$($YABAI -m query --displays --display 2>/dev/null)
if [ -z "$CURRENT_DISPLAY_INFO" ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to get current display info"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    exit 1
fi

# Extract current display frame info (handle floats by doing math in jq)
CURRENT_X=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.x')
CURRENT_Y=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.y')
CURRENT_WIDTH=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.w')
CURRENT_HEIGHT=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.h')
CURRENT_X_CENTER=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.x + (.frame.w / 2)')
CURRENT_Y_CENTER=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.y + (.frame.h / 2)')

case "$DIRECTION" in
    east)
        CURRENT_EDGE=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.x + .frame.w')
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current display right edge: $CURRENT_EDGE, y-center: $CURRENT_Y_CENTER"
        
        # Find displays to the east
        TARGET_DISPLAYS=$($YABAI -m query --displays | $JQ -r --argjson edge "$CURRENT_EDGE" --argjson y_center "$CURRENT_Y_CENTER" '
            map(select(.frame.x >= $edge) | 
            . + {
                distance: (.frame.x - $edge),
                y_overlap: (
                    if (.frame.y <= $y_center and .frame.y + .frame.h >= $y_center) then 0
                    elif (.frame.y > $y_center) then (.frame.y - $y_center)
                    else ($y_center - (.frame.y + .frame.h))
                    end
                )
            }) |
            sort_by(.distance, .y_overlap) |
            .[0]'
        )
        EDGE_WINDOW_SORT='sort_by(.frame.x, .frame.y)'
        EDGE_WINDOW_DESC="westmost"
        ;;
    west)
        CURRENT_EDGE=$CURRENT_X
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current display left edge: $CURRENT_EDGE, y-center: $CURRENT_Y_CENTER"
        
        # Find displays to the west
        TARGET_DISPLAYS=$($YABAI -m query --displays | $JQ -r --argjson edge "$CURRENT_EDGE" --argjson y_center "$CURRENT_Y_CENTER" '
            map(select(.frame.x + .frame.w <= $edge) | 
            . + {
                distance: ($edge - (.frame.x + .frame.w)),
                y_overlap: (
                    if (.frame.y <= $y_center and .frame.y + .frame.h >= $y_center) then 0
                    elif (.frame.y > $y_center) then (.frame.y - $y_center)
                    else ($y_center - (.frame.y + .frame.h))
                    end
                )
            }) |
            sort_by(.distance, .y_overlap) |
            .[0]'
        )
        EDGE_WINDOW_SORT='sort_by(-.frame.x, .frame.y)'
        EDGE_WINDOW_DESC="eastmost"
        ;;
    north)
        CURRENT_EDGE=$CURRENT_Y
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current display top edge: $CURRENT_EDGE, x-center: $CURRENT_X_CENTER"
        
        # Find displays to the north
        TARGET_DISPLAYS=$($YABAI -m query --displays | $JQ -r --argjson edge "$CURRENT_EDGE" --argjson x_center "$CURRENT_X_CENTER" '
            map(select(.frame.y + .frame.h <= $edge) | 
            . + {
                distance: ($edge - (.frame.y + .frame.h)),
                x_overlap: (
                    if (.frame.x <= $x_center and .frame.x + .frame.w >= $x_center) then 0
                    elif (.frame.x > $x_center) then (.frame.x - $x_center)
                    else ($x_center - (.frame.x + .frame.w))
                    end
                )
            }) |
            sort_by(.distance, .x_overlap) |
            .[0]'
        )
        # For north, pick the window closest to the bottom of that display
        EDGE_WINDOW_SORT='sort_by(-.frame.y, .frame.x)'
        EDGE_WINDOW_DESC="bottommost"
        ;;
    south)
        CURRENT_EDGE=$(echo "$CURRENT_DISPLAY_INFO" | $JQ -r '.frame.y + .frame.h')
        "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current display bottom edge: $CURRENT_EDGE, x-center: $CURRENT_X_CENTER"
        
        # Find displays to the south
        TARGET_DISPLAYS=$($YABAI -m query --displays | $JQ -r --argjson edge "$CURRENT_EDGE" --argjson x_center "$CURRENT_X_CENTER" '
            map(select(.frame.y >= $edge) | 
            . + {
                distance: (.frame.y - $edge),
                x_overlap: (
                    if (.frame.x <= $x_center and .frame.x + .frame.w >= $x_center) then 0
                    elif (.frame.x > $x_center) then (.frame.x - $x_center)
                    else ($x_center - (.frame.x + .frame.w))
                    end
                )
            }) |
            sort_by(.distance, .x_overlap) |
            .[0]'
        )
        # For south, pick the window closest to the top of that display
        EDGE_WINDOW_SORT='sort_by(.frame.y, .frame.x)'
        EDGE_WINDOW_DESC="topmost"
        ;;
esac

if [ "$TARGET_DISPLAYS" = "null" ] || [ -z "$TARGET_DISPLAYS" ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No display found to the $DIRECTION"
    log_state "AFTER"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished (no $DIRECTION display)"
    exit 0
fi

# Get the target display index
TARGET_DISPLAY_INDEX=$(echo "$TARGET_DISPLAYS" | $JQ -r '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Found display to the $DIRECTION: $TARGET_DISPLAY_INDEX"

# Get all visible windows on the target display
TARGET_WINDOWS=$($YABAI -m query --windows --display "$TARGET_DISPLAY_INDEX" | $JQ -r "
    map(select(.[\"is-visible\"] == true and .[\"is-minimized\"] == false)) |
    $EDGE_WINDOW_SORT"
)

if [ "$TARGET_WINDOWS" = "[]" ] || [ -z "$TARGET_WINDOWS" ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No visible windows on display $TARGET_DISPLAY_INDEX"
    log_state "AFTER"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished (no windows on $DIRECTION display)"
    exit 0
fi

# Get the appropriate edge window or largest window
if [ "$DIRECTION" = "north" ] || [ "$DIRECTION" = "south" ]; then
    # For vertical directions, if no specific edge preference, pick the largest window
    TARGET_WINDOW_ID=$(echo "$TARGET_WINDOWS" | $JQ -r '
        if length == 1 then
            .[0].id
        else
            max_by(.frame.w * .frame.h).id
        end'
    )
else
    # For horizontal directions, use the edge window
    TARGET_WINDOW_ID=$(echo "$TARGET_WINDOWS" | $JQ -r '.[0].id')
fi

if [ "$TARGET_WINDOW_ID" = "null" ] || [ -z "$TARGET_WINDOW_ID" ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to find $EDGE_WINDOW_DESC window on target display"
    log_state "AFTER"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing $EDGE_WINDOW_DESC window $TARGET_WINDOW_ID on display $TARGET_DISPLAY_INDEX"

# Focus the target window
if $YABAI -m window --focus "$TARGET_WINDOW_ID" 2>/dev/null; then
    log_state "AFTER"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully focused window $TARGET_WINDOW_ID on $DIRECTION display"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
    exit 0
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to focus window $TARGET_WINDOW_ID"
    log_state "AFTER"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished with error"
    exit 1
fi