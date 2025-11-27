#!/usr/bin/env bash

# window_resize_to_next_tenth_narrower.sh
# Shrinks the current window width to the previous 1/10th of the display width (min 1/10th).

# Script setup
SCRIPT_NAME="window_resize_to_next_tenth_narrower.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state
log_state() {
    local type="$1"
    local window_info=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r 'if . then {id: .id, width: .frame.w, height: .frame.h, x: .frame.x, y: .frame.y} else "unknown" end' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Window state: $window_info"
}

# Log state before action
log_state "BEFORE_STATE"

# Get focused window info
win_json=$($YABAI -m query --windows --window)
if [[ -z "$win_json" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No focused window"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no window"
  exit 1
fi

win_id=$(echo "$win_json" | $JQ '.id')
win_x=$(echo "$win_json" | $JQ '.frame.x')
win_y=$(echo "$win_json" | $JQ '.frame.y')
win_w=$(echo "$win_json" | $JQ '.frame.w')
win_h=$(echo "$win_json" | $JQ '.frame.h')
display_id=$(echo "$win_json" | $JQ '.display')

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window $win_id frame: x=$win_x y=$win_y w=$win_w h=$win_h display=$display_id"

display_json=$($YABAI -m query --displays --display $display_id)
display_w=$(echo "$display_json" | $JQ '.frame.w')
display_h=$(echo "$display_json" | $JQ '.frame.h')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Display $display_id frame: w=$display_w h=$display_h"

# Calculate current width as a fraction of display
cur_frac=$(awk "BEGIN { printf \"%.4f\", $win_w/$display_w }")
cur_tenth=$(awk "BEGIN { printf \"%d\", ($cur_frac*10)+0 }")
prev_tenth=$((cur_tenth-1))
if (( prev_tenth < 1 )); then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Already at or below 1/10th. No action needed"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - already at minimum"
  exit 0
fi

new_w=$(awk "BEGIN { printf \"%d\", $display_w * $prev_tenth / 10 }")
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Resizing window $win_id to width $new_w (prev tenth: $prev_tenth/10)"

$YABAI -m window $win_id --resize abs:${new_w}:${win_h}
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command executed"

# Log state after action
log_state "AFTER_STATE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 