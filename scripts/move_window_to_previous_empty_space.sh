#!/usr/bin/env bash
# ---------- move_window_to_previous_empty_space.sh ----------
# Moves the current window to the previous empty space on the current display.
# If no empty space is found before the current one, it does nothing.

# --- Config ---
DEBUG=false # Set to true to enable logging to ~/.config/logs/move_window_to_previous_empty_space.log

# --- Logging Setup ---
LOG_FILE="$HOME/.config/logs/move_window_to_previous_empty_space.log" # Changed log file name

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

# 3. Find the index of the previous empty space on the current display
log "Finding previous empty space index..."
prev_empty=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
  map(select(.index < $cur and (.windows | length == 0))) # Filter spaces: index < current AND window count is 0
  | sort_by(.index) # Sort by index
  | .[-1].index // "" # Get the index of the last one (closest previous), or fallback to literal ""
')
log "Previous empty space index: '$prev_empty'"

# 4. Determine target space and move/focus
target_space=""
if [[ "$prev_empty" == '""' ]]; then # Check if prev_empty IS literally ""
  # No empty space found before current
  log "No empty space found before current space $cur. Exiting."
  echo "No empty space found before current space."
  exit 0 # Exit gracefully, no action needed
else
  # Found an empty space
  target_space="$prev_empty"
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