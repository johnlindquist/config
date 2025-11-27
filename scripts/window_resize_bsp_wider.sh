#!/usr/bin/env bash

# window_resize_bsp_wider.sh
# Makes the current managed window wider (or taller for vertical splits) within Yabai's BSP layout.

# Script setup
SCRIPT_NAME="window_resize_bsp_wider.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state
log_state() {
    local type="$1"
    local window_info=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r 'if . then {id: .id, width: .frame.w, height: .frame.h, split: ."split-type", floating: ."is-floating"} else "unknown" end' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Window state: $window_info"
}

# Log state before action
log_state "BEFORE_STATE"

win_json=$($YABAI -m query --windows --window 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "win_json: $win_json"
if [[ -z "$win_json" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No focused window"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no window"
  exit 1
fi

win_id=$(echo "$win_json" | $JQ '.id')
win_w=$(echo "$win_json" | $JQ '.frame.w')
win_h=$(echo "$win_json" | $JQ '.frame.h')
display_id=$(echo "$win_json" | $JQ '.display')
floating=$(echo "$win_json" | $JQ '."is-floating"')
split_type=$(echo "$win_json" | $JQ -r '."split-type"')

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window $win_id w=$win_w h=$win_h display=$display_id floating=$floating split_type=$split_type"

if [[ "$floating" == "true" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Window is floating. Not resizing"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - floating window"
  exit 0
fi

display_json=$($YABAI -m query --displays --display $display_id 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "display_json: $display_json"
display_w=$(echo "$display_json" | $JQ '.frame.w')
display_h=$(echo "$display_json" | $JQ '.frame.h')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Display $display_id w=$display_w h=$display_h"

# Detect if the window is alone in its split
# Get all windows on the same space
space_id=$(echo "$win_json" | $JQ '.space')
all_windows_json=$($YABAI -m query --windows --space $space_id 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "all_windows_json: $all_windows_json"

# Count windows in the same split direction (rough heuristic: count windows with overlapping y for horizontal, x for vertical)
sibling_count=0
if [[ "$split_type" == "horizontal" ]]; then
  win_y=$(echo "$win_json" | $JQ '.frame.y')
  win_h=$(echo "$win_json" | $JQ '.frame.h')
  sibling_count=$(echo "$all_windows_json" | $JQ --argjson y "$win_y" --argjson h "$win_h" --argjson id "$win_id" '[.[] | select(.id != $id and (.frame.y < ($y + $h) and ($y < (.frame.y + .frame.h))))] | length')
elif [[ "$split_type" == "vertical" ]]; then
  win_x=$(echo "$win_json" | $JQ '.frame.x')
  win_w=$(echo "$win_json" | $JQ '.frame.w')
  sibling_count=$(echo "$all_windows_json" | $JQ --argjson x "$win_x" --argjson w "$win_w" --argjson id "$win_id" '[.[] | select(.id != $id and (.frame.x < ($x + $w) and ($x < (.frame.x + .frame.w))))] | length')
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Sibling count in split direction: $sibling_count"

if [[ "$sibling_count" -eq 0 ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Cannot resize: no adjacent window in split. Add another window to enable resizing"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - no siblings"
  exit 0
fi

if [[ "$split_type" == "horizontal" ]]; then
  step=$(awk "BEGIN { printf \"%d\", $display_w/10 }")
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Horizontal split. Trying to resize right by $step px"
  resize_cmd="$YABAI -m window $win_id --resize right:+$step:0"
  resize_output=$($YABAI -m window $win_id --resize right:+$step:0 2>&1)
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command: $resize_cmd"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize output: $resize_output"
  if echo "$resize_output" | grep -q "cannot locate a bsp node fence"; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Right resize failed, trying left"
    resize_cmd="$YABAI -m window $win_id --resize left:-$step:0"
    resize_output=$($YABAI -m window $win_id --resize left:-$step:0 2>&1)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command: $resize_cmd"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize output: $resize_output"
  fi
elif [[ "$split_type" == "vertical" ]]; then
  step=$(awk "BEGIN { printf \"%d\", $display_h/10 }")
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Vertical split. Trying to resize bottom by $step px"
  resize_cmd="$YABAI -m window $win_id --resize bottom:+0:$step"
  resize_output=$($YABAI -m window $win_id --resize bottom:+0:$step 2>&1)
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command: $resize_cmd"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize output: $resize_output"
  if echo "$resize_output" | grep -q "cannot locate a bsp node fence"; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Bottom resize failed, trying top"
    resize_cmd="$YABAI -m window $win_id --resize top:-0:$step"
    resize_output=$($YABAI -m window $win_id --resize top:-0:$step 2>&1)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize command: $resize_cmd"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Resize output: $resize_output"
  fi
else
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Unknown split-type: $split_type"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - unknown split type"
  exit 0
fi

# Log state after action
log_state "AFTER_STATE"

new_win_json=$($YABAI -m query --windows --window $win_id 2>&1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "new_win_json: $new_win_json"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 