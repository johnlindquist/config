#!/usr/bin/env bash
# ---------- move_window_to_next_empty_space.sh ----------
# Moves the current window to the next empty space on the current display,
# creating a new space at the end if no empty space is found.

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/move_window_to_next_empty_space.log

# --- Logging Setup ---
LOG_FILE="$HOME/.config/logs/move_window_to_next_empty_space.log"

log() {
  if [[ "$DEBUG" == "true" ]]; then
    # Ensure log dir exists only when debugging
    mkdir -p "$(dirname "$LOG_FILE")"
    # Append timestamp and message
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $@" >> "$LOG_FILE"
  fi
}

if [[ "$DEBUG" == "true" ]]; then
  # Redirect stderr to log file only when debugging
  exec 2>> "$LOG_FILE"
  log "--- Script Start ---"
fi

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# --- Helper Function ---
focus_window() {
  local window_id="$1"
  if [[ -n "$window_id" ]]; then
    log "Refocusing window $window_id..."
    $y -m window --focus "$window_id"
    log "Refocus window command executed."
  fi
}

# 1. Get Focused Window ID
log "Getting focused window ID..."
window_id=$($y -m query --windows --window | $jq '.id')
if [[ -z "$window_id" || "$window_id" == "null" ]]; then
    log "Error: Could not get focused window ID."
    echo "Error: No focused window found." >&2
    exit 1
fi
log "Focused window ID: $window_id"

# 2. Get Current Space Index
log "Querying current space index..."
cur=$($y -m query --spaces --space | $jq '.index')
log "Current space index: $cur"

# 3. Find the index of the next empty space on the current display
log "Finding next empty space index..."
next_empty=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
  map(select(.index > $cur and (.windows | length == 0))) # Filter spaces: index > current AND window count is 0
  | sort_by(.index) # Sort by index
  | .[0].index // "" # Get the index of the first one, or fallback to literal ""
')
log "Next empty space index: '$next_empty'"

# 4. Determine target space and move/focus
target_space=""
if [[ "$next_empty" == '""' ]]; then # Check if next_empty IS literally ""
  # No empty space found after current -> create new one
  log "No empty space found after current, creating new space..."
  $y -m space --create
  log "Create command executed."
  log "Querying last space index (the new one)..."
  last=$($y -m query --spaces --display | $jq '.[-1].index')
  log "Last space index: $last"
  target_space="$last"
  log "Target space set to: $target_space (newly created)"
else
  # Found an empty space
  target_space="$next_empty"
  log "Target space set to: $target_space (existing empty space)"
fi

# 5. Move window to target space
log "Moving window $window_id to space $target_space..."
$y -m window "$window_id" --space "$target_space"
log "Move command executed."

# 6. Focus the target space
log "Focusing space $target_space..."
$y -m space --focus "$target_space"
log "Focus space command executed."

# 7. Refocus the moved window
focus_window "$window_id"

log "--- Script End ---" 