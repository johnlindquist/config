#!/usr/bin/env bash

# window_resize_bsp_wider.sh
# Makes the current managed window wider (or taller for vertical splits) within Yabai's BSP layout.

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
LOG_FILE="$HOME/.config/logs/window_resize_bsp_wider.log"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $@" >> "$LOG_FILE"
}

log "--- Script Start --- PATH: $PATH"

win_json=$($YABAI -m query --windows --window 2>&1)
log "win_json: $win_json"
if [[ -z "$win_json" ]]; then
  log "No focused window. Exiting."
  exit 1
fi

win_id=$(echo "$win_json" | $JQ '.id')
win_w=$(echo "$win_json" | $JQ '.frame.w')
win_h=$(echo "$win_json" | $JQ '.frame.h')
display_id=$(echo "$win_json" | $JQ '.display')
floating=$(echo "$win_json" | $JQ '."is-floating"')
split_type=$(echo "$win_json" | $JQ -r '."split-type"')

log "Window $win_id w=$win_w h=$win_h display=$display_id floating=$floating split_type=$split_type"

if [[ "$floating" == "true" ]]; then
  log "Window is floating. Not resizing. Exiting."
  exit 0
fi

display_json=$($YABAI -m query --displays --display $display_id 2>&1)
log "display_json: $display_json"
display_w=$(echo "$display_json" | $JQ '.frame.w')
display_h=$(echo "$display_json" | $JQ '.frame.h')
log "Display $display_id w=$display_w h=$display_h"

# Detect if the window is alone in its split
# Get all windows on the same space
space_id=$(echo "$win_json" | $JQ '.space')
all_windows_json=$($YABAI -m query --windows --space $space_id 2>&1)
log "all_windows_json: $all_windows_json"

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
log "Sibling count in split direction: $sibling_count"

if [[ "$sibling_count" -eq 0 ]]; then
  log "Cannot resize: no adjacent window in split. Add another window to enable resizing. Exiting."
  exit 0
fi

if [[ "$split_type" == "horizontal" ]]; then
  step=$(awk "BEGIN { printf \"%d\", $display_w/10 }")
  log "Horizontal split. Trying to resize right by $step px."
  resize_cmd="$YABAI -m window $win_id --resize right:+$step:0"
  resize_output=$($YABAI -m window $win_id --resize right:+$step:0 2>&1)
  log "Resize command: $resize_cmd"
  log "Resize output: $resize_output"
  if echo "$resize_output" | grep -q "cannot locate a bsp node fence"; then
    log "Right resize failed, trying left."
    resize_cmd="$YABAI -m window $win_id --resize left:-$step:0"
    resize_output=$($YABAI -m window $win_id --resize left:-$step:0 2>&1)
    log "Resize command: $resize_cmd"
    log "Resize output: $resize_output"
  fi
elif [[ "$split_type" == "vertical" ]]; then
  step=$(awk "BEGIN { printf \"%d\", $display_h/10 }")
  log "Vertical split. Trying to resize bottom by $step px."
  resize_cmd="$YABAI -m window $win_id --resize bottom:+0:$step"
  resize_output=$($YABAI -m window $win_id --resize bottom:+0:$step 2>&1)
  log "Resize command: $resize_cmd"
  log "Resize output: $resize_output"
  if echo "$resize_output" | grep -q "cannot locate a bsp node fence"; then
    log "Bottom resize failed, trying top."
    resize_cmd="$YABAI -m window $win_id --resize top:-0:$step"
    resize_output=$($YABAI -m window $win_id --resize top:-0:$step 2>&1)
    log "Resize command: $resize_cmd"
    log "Resize output: $resize_output"
  fi
else
  log "Unknown split-type: $split_type. Exiting."
  exit 0
fi

new_win_json=$($YABAI -m query --windows --window $win_id 2>&1)
log "new_win_json: $new_win_json"
log "--- Script End ---" 