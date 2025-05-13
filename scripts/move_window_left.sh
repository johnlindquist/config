#!/usr/bin/env bash
# ---------- move_window_left.sh ----------
# Moves the current window to the previous space, creating one if necessary.

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/move_window_left.log

# --- Logging Setup ---
if [[ "$DEBUG" == "true" ]]; then
  LOG_FILE="$HOME/.config/logs/move_window_left.log"
  # Create log dir if it doesn't exist
  mkdir -p "$(dirname "$LOG_FILE")"
  exec >> "$LOG_FILE" 2>&1
  echo "--- $(date) ---"
  echo "Starting move_window_left.sh (DEBUG enabled)"
fi

log() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "$@"
  fi
}

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

log "Getting focused window ID..."
window_id=$($y -m query --windows --window | $jq '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    log "Error: Could not get focused window ID."
    exit 1
fi
log "Focused window ID: $window_id"

log "Querying current space index..."
cur=$($y -m query --spaces --space | $jq '.index')
log "Current space index: $cur"

log "Querying previous space index..."
prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index < $cur))            # only spaces to the left
        | sort_by(.index) | .[-1].index // "" # pick the closest, or ""')
log "Previous space index: '$prev'"

# Use literal string comparison for the jq fallback ""
if [[ "$prev" == '""' ]]; then # Check if prev IS literally ""
  # Edge -> create space, move it to pos 1, then move window
  log "Edge detected (prev is \"\"), creating new space..."
  $y -m space --create
  log "Create command executed."
  # Need to focus the new space briefly to move it
  log "Querying last space index (which is the new one)..."
  new=$($y -m query --spaces --display | $jq '.[-1].index')
  log "New space index: $new"
  log "Focusing new space ($new) temporarily..."
  $y -m space --focus "$new"
  log "Temporary focus command executed."
  log "Moving new space ($new) to position 1..."
  $y -m space --move 1
  log "Move command executed."
  log "Moving window $window_id to space 1..."
  $y -m window "$window_id" --space 1
  log "Move command executed."
  log "Focusing space 1..." # Focus the space after moving
  $y -m space --focus 1
  log "Focus space command executed."
  log "Refocusing window $window_id..."
  $y -m window --focus "$window_id"
  log "Refocus window command executed."
else # Prev is NOT ""
  # Neighbour exists -> move window there
  log "Neighbour found ('$prev'), moving window $window_id to space $prev..."
  $y -m window "$window_id" --space "$prev"
  log "Move command executed."
  log "Focusing space $prev..." # Focus the space after moving
  $y -m space --focus "$prev"
  log "Focus space command executed."
  log "Refocusing window $window_id..."
  $y -m window --focus "$window_id"
  log "Refocus window command executed."
fi

log "Script finished."
if [[ "$DEBUG" == "true" ]]; then
  echo ""
fi 