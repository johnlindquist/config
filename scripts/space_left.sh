#!/usr/bin/env bash
# ---------- space_left.sh ----------

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/space_left.log

# --- Logging Setup ---
if [[ "$DEBUG" == "true" ]]; then
  LOG_FILE="$HOME/.config/logs/space_left.log"
  exec >> "$LOG_FILE" 2>&1
  echo "--- $(date) ---"
  echo "Starting space_left.sh (DEBUG enabled)"
fi

log() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "$@"
  fi
}

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

log "Querying current space index..."
cur=$($y -m query --spaces --space   | $jq '.index')
log "Current space index: $cur"

log "Querying previous space index..."
prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index < $cur))            # only spaces to the left
        | sort_by(.index) | .[-1].index // "" # pick the closest, or ""')
log "Previous space index: '$prev'"

# Use literal string comparison for the jq fallback ""
if [[ "$prev" == '""' ]]; then # Check if prev IS literally ""
  # Edge -> spawn & land
  log "Edge detected (prev is \"\"), creating new space..."
  $y -m space --create
  log "Create command executed."
  # Note: focusing 'last' then moving to 1 is necessary
  log "Querying last space index (which is the new one)..."
  new=$($y -m query --spaces --display | $jq '.[-1].index') 
  log "New space index: $new"
  log "Focusing new space ($new)..."
  $y -m space --focus "$new" # Focus temporarily to allow move
  log "Focus command executed."
  log "Moving new space ($new) to position 1..."
  $y -m space --move 1
  log "Move command executed."
  log "Focusing space 1..."
  $y -m space --focus 1
  log "Focus command executed."
else # Prev is NOT ""
  # Neighbour exists -> just hop
  log "Neighbour found ('$prev'), focusing..."
  $y -m space --focus "$prev"
  log "Focus command executed."
fi

log "Script finished."
if [[ "$DEBUG" == "true" ]]; then
  echo ""
fi
