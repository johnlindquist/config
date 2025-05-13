#!/usr/bin/env bash
# ---------- space_right.sh ----------

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/space_right.log

# --- Logging Setup ---
if [[ "$DEBUG" == "true" ]]; then
  LOG_FILE="$HOME/.config/logs/space_right.log"
  exec >> "$LOG_FILE" 2>&1
  echo "--- $(date) ---"
  echo "Starting space_right.sh (DEBUG enabled)"
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

log "Querying next space index..."
next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
        map(select(.index > $cur))            # only spaces to the right
        | sort_by(.index) | .[0].index // ""  # pick the closest, or ""')
log "Next space index: '$next'"

# Use literal string comparison for the jq fallback ""
if [[ "$next" == '""' ]]; then # Check if next IS literally ""
  # Edge -> spawn & land
  log "Edge detected (next is \"\"), creating new space..."
  $y -m space --create
  log "Create command executed."
  log "Querying last space index..."
  last=$($y -m query --spaces --display | $jq '.[-1].index')
  log "Last space index: $last"
  log "Focusing last space ($last)..."
  $y -m space --focus "$last"
  log "Focus command executed."
else # Next is NOT ""
  # Neighbour exists -> just hop
  log "Neighbour found ('$next'), focusing..."
  $y -m space --focus "$next"
  log "Focus command executed."
fi

log "Script finished."
if [[ "$DEBUG" == "true" ]]; then
  echo ""
fi
