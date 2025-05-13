#!/usr/bin/env bash
# ---------- move_window_right.sh ----------
# Moves the current window to the next space, creating one if necessary.

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/move_window_right.log

# --- Logging Setup ---
if [[ "$DEBUG" == "true" ]]; then
  LOG_FILE="$HOME/.config/logs/move_window_right.log"
  # Create log dir if it doesn't exist
  mkdir -p "$(dirname "$LOG_FILE")"
  exec >> "$LOG_FILE" 2>&1
  echo "--- $(date) ---"
  echo "Starting move_window_right.sh (DEBUG enabled)"
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

log "Querying next space index..."
next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index > $cur))            # only spaces to the right
        | sort_by(.index) | .[0].index // ""  # pick the closest, or ""')
log "Next space index: '$next'"

# Use literal string comparison for the jq fallback ""
if [[ "$next" == '""' ]]; then # Check if next IS literally ""
  # Edge -> create space, then move window
  log "Edge detected (next is \"\"), creating new space..."
  $y -m space --create
  log "Create command executed."
  log "Querying last space index..."
  last=$($y -m query --spaces --display | $jq '.[-1].index')
  log "Last space index: $last"
  log "Moving window $window_id to space $last..."
  $y -m window "$window_id" --space "$last"
  log "Move command executed."
  log "Focusing space $last..." # Focus the space after moving
  $y -m space --focus "$last"
  log "Focus space command executed."
  log "Refocusing window $window_id..."
  $y -m window --focus "$window_id"
  log "Refocus window command executed."
else # Next is NOT ""
  # Neighbour exists -> move window there
  log "Neighbour found ('$next'), moving window $window_id to space $next..."
  $y -m window "$window_id" --space "$next"
  log "Move command executed."
  log "Focusing space $next..." # Focus the space after moving
  $y -m space --focus "$next"
  log "Focus space command executed."
  log "Refocusing window $window_id..."
  $y -m window --focus "$window_id"
  log "Refocus window command executed."
fi

log "Script finished."
if [[ "$DEBUG" == "true" ]]; then
  echo ""
fi 