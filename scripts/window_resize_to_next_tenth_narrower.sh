#!/usr/bin/env bash

# window_resize_to_next_tenth_narrower.sh
# Shrinks the current window width to the previous 1/10th of the display width (min 1/10th).

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
LOG_FILE="$HOME/.config/logs/window_resize_to_next_tenth_narrower.log"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $@" >> "$LOG_FILE"
}

log "--- Script Start --- PATH: $PATH"

# Get focused window info
win_json=$($YABAI -m query --windows --window)
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

log "Window $win_id frame: x=$win_x y=$win_y w=$win_w h=$win_h display=$display_id"

display_json=$($YABAI -m query --displays --display $display_id)
display_w=$(echo "$display_json" | $JQ '.frame.w')
display_h=$(echo "$display_json" | $JQ '.frame.h')
log "Display $display_id frame: w=$display_w h=$display_h"

# Calculate current width as a fraction of display
cur_frac=$(awk "BEGIN { printf \"%.4f\", $win_w/$display_w }")
cur_tenth=$(awk "BEGIN { printf \"%d\", ($cur_frac*10)+0 }")
prev_tenth=$((cur_tenth-1))
if (( prev_tenth < 1 )); then
  log "Already at or below 1/10th. No action."
  exit 0
fi

new_w=$(awk "BEGIN { printf \"%d\", $display_w * $prev_tenth / 10 }")
log "Resizing window $win_id to width $new_w (prev tenth: $prev_tenth/10)"

$YABAI -m window $win_id --resize abs:${new_w}:${win_h}
log "Resize command executed."
log "--- Script End ---" 