#!/usr/bin/env bash
# ---------- remove_current_space.sh ----------
# Destroys the current yabai space.

# --- Config ---
DEBUG=false # Set to true to enable logging

# --- Logging Setup ---
LOG_FILE="$HOME/.config/logs/remove_current_space.log"

log() {
  if [[ "$DEBUG" == "true" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $@" >> "$LOG_FILE"
  fi
}

if [[ "$DEBUG" == "true" ]]; then
  exec 2>> "$LOG_FILE"
  log "--- Script Start ---"
fi

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# 1. Get Current Space Index
log "Querying current space index..."
current_space_index=$($y -m query --spaces --space | $jq '.index')
log "Current space index: $current_space_index"

if [[ -z "$current_space_index" || "$current_space_index" == "null" ]]; then
    log "Error: Could not get current space index."
    echo "Error: Could not determine current space." >&2
    exit 1
fi

# 2. Attempt to destroy the current space
log "Attempting to destroy space $current_space_index..."
$y -m space --destroy "$current_space_index"

# Yabai will prevent destroying the last space on a display automatically.
# The command might print an error to stderr if it fails, which will be logged if DEBUG=true.
log "Destroy command executed for space $current_space_index."

log "--- Script End ---" 