#!/usr/bin/env bash

# window_resize_to_next_tenth_wider.sh
# Expands the current window width to the next 1/10th of the display width (max 100%).

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
LOG_FILE="$HOME/.config/logs/window_resize_to_next_tenth_wider.log"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $@" >> "$LOG_FILE"
}

log "--- Script Start --- PATH: $PATH"

# Get focused window info
win_json=$($YABAI -m query --windows --window 2>&1)
log "win_json: $win_json"
if [[ -z "$win_json" ]]; then
  log "No focused window. Exiting."
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

log "Window $win_id frame: x=$win_x y=$win_y w=$win_w h=$win_h display=$display_id floating=$floating split_type=$split_type"

# Check for valid window id and width
if [[ -z "$win_id" || -z "$win_w" || -z "$win_h" || -z "$display_id" ]]; then
  log "Missing window/frame/display info. Exiting."
  exit 1
fi

display_json=$($YABAI -m query --displays --display $display_id 2>&1)
log "display_json: $display_json"
display_w=$(echo "$display_json" | $JQ '.frame.w')
display_h=$(echo "$display_json" | $JQ '.frame.h')
log "Display $display_id frame: w=$display_w h=$display_h"

# Check for valid display width
if [[ -z "$display_w" ]]; then
  log "Missing display width. Exiting."
  exit 1
fi

# Calculate current width as a fraction of display
cur_frac=$(awk "BEGIN { printf \"%.4f\", $win_w/$display_w }")
log "cur_frac: $cur_frac"
cur_tenth=$(awk "BEGIN { printf \"%d\", ($cur_frac*10)+0 }")
log "cur_tenth: $cur_tenth"
next_tenth=$((cur_tenth+1))
log "next_tenth: $next_tenth"
if (( next_tenth > 10 )); then
  log "Already at or above 100%. No action. Exiting."
  exit 0
fi

new_w=$(awk "BEGIN { printf \"%d\", $display_w * $next_tenth / 10 }")
log "new_w: $new_w"

if [[ "$floating" == "true" ]]; then
  log "Window is floating. Using abs resize."
  resize_cmd="$YABAI -m window $win_id --resize abs:${new_w}:${win_h}"
  resize_output=$($YABAI -m window $win_id --resize abs:${new_w}:${win_h} 2>&1)
else
  # Managed window: use relative resize (right:+N:0) only if split-type is horizontal
  if [[ "$split_type" != "horizontal" ]]; then
    log "Window split-type is $split_type. Only horizontal splits can be resized wider. Exiting."
    exit 0
  fi
  delta=$(awk "BEGIN { printf \"%d\", $new_w - $win_w }")
  log "win_w: $win_w, new_w: $new_w, delta: $delta"
  if (( delta <= 0 )); then
    log "No positive delta to grow. Exiting."
    exit 0
  fi
  log "Window is managed. Using relative resize right:+$delta:0."
  resize_cmd="$YABAI -m window $win_id --resize right:+$delta:0"
  resize_output=$($YABAI -m window $win_id --resize right:+$delta:0 2>&1)
fi
log "Resize command: $resize_cmd"
log "Resize command output: $resize_output"

# Log new window size after resize
new_win_json=$($YABAI -m query --windows --window $win_id 2>&1)
log "new_win_json: $new_win_json"

log "--- Script End ---" 