#!/usr/bin/env bash

# window_resize_to_next_tenth_wider.sh
# Expands the current window width to the next 1/10th of the display width (max 100%).

# Script setup
SCRIPT_NAME="window_resize_to_next_tenth_wider.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state
log_state() {
    local type="$1"
    local window_info=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r 'if . then {id: .id, width: .frame.w, height: .frame.h, x: .frame.x, y: .frame.y, floating: ."is-floating", split: ."split-type"} else "unknown" end' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Window state: $window_info"
}

# Log state before action
log_state "BEFORE_STATE"

# Get focused window info
win_json=$($YABAI -m query --windows --window 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "win_json: $win_json"
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
floating=$(echo "$win_json" | $JQ '."is-floating"')
split_type=$(echo "$win_json" | $JQ -r '."split-type"')

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window $win_id frame: x=$win_x y=$win_y w=$win_w h=$win_h display=$display_id floating=$floating split_type=$split_type"

# Check for valid window id and width
if [[ -z "$win_id" || -z "$win_w" || -z "$win_h" || -z "$display_id" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Missing window/frame/display info"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - invalid data"
  exit 1
fi

display_json=$($YABAI -m query --displays --display $display_id 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "display_json: $display_json"
display_w=$(echo "$display_json" | $JQ '.frame.w')
display_h=$(echo "$display_json" | $JQ '.frame.h')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Display $display_id frame: w=$display_w h=$display_h"

# Check for valid display width
if [[ -z "$display_w" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Missing display width"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no display width"
  exit 1
fi

# Calculate current width as a fraction of display
cur_frac=$(awk "BEGIN { printf \"%.4f\", $win_w/$display_w }")
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "cur_frac: $cur_frac"
cur_tenth=$(awk "BEGIN { printf \"%d\", ($cur_frac*10)+0 }")
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "cur_tenth: $cur_tenth"
next_tenth=$((cur_tenth+1))
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "next_tenth: $next_tenth"
if (( next_tenth > 10 )); then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Already at or above 100%. No action needed"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - already at maximum"
  exit 0
fi

new_w=$(awk "BEGIN { printf \"%d\", $display_w * $next_tenth / 10 }")
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "new_w: $new_w"

if [[ "$floating" == "true" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Window is floating. Using abs resize to ${new_w}x${win_h}"
  resize_cmd="$YABAI -m window $win_id --resize abs:${new_w}:${win_h}"
  resize_output=$($YABAI -m window $win_id --resize abs:${new_w}:${win_h} 2>&1)
else
  # Managed window: use relative resize (right:+N:0) only if split-type is horizontal
  if [[ "$split_type" != "horizontal" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Window split-type is $split_type. Only horizontal splits can be resized wider"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - incompatible split type"
    exit 0
  fi
  delta=$(awk "BEGIN { printf \"%d\", $new_w - $win_w }")
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "win_w: $win_w, new_w: $new_w, delta: $delta"
  if (( delta <= 0 )); then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "No positive delta to grow"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - no change needed"
    exit 0
  fi
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Window is managed. Using relative resize right:+$delta:0"
  resize_cmd="$YABAI -m window $win_id --resize right:+$delta:0"
  resize_output=$($YABAI -m window $win_id --resize right:+$delta:0 2>&1)
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command: $resize_cmd"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command output: $resize_output"

# Log new window size after resize
new_win_json=$($YABAI -m query --windows --window $win_id 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "new_win_json: $new_win_json"

# Log state after action
log_state "AFTER_STATE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 