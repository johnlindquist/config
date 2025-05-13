#!/usr/bin/env bash
# ---------- move_window_right_half.sh (now move_window_bsp_east.sh conceptually) ----------
# Moves the focused window east within the BSP tree.

# --- Config ---
DEBUG=false # Set to true to enable logging

# --- Logging Setup ---
LOG_FILE="$HOME/.config/logs/move_window_bsp.log" # Shared log file

log() {
  if [[ "$DEBUG" == "true" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [Warp East] $@" >> "$LOG_FILE"
  fi
}

if [[ "$DEBUG" == "true" ]]; then
  exec 2>> "$LOG_FILE"
  log "--- Script Start ---"
fi

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# 1. Get Focused Window ID
log "Getting focused window ID..."
window_id=$($y -m query --windows --window | $jq '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    log "Error: Could not get focused window ID."
    echo "Error: No focused window found." >&2
    exit 1
fi
log "Focused window ID: $window_id"

# 2. Warp the window east
log "Warping window $window_id east..."
$y -m window --warp east
log "Warp command executed."

# 3. Refocus the window (Yabai often keeps focus, but good practice)
log "Refocusing window $window_id..."
$y -m window --focus "$window_id"
log "Refocus command executed."

log "--- Script End ---" 