# Define log directory and file
LOG_DIR="/Users/johnlindquist/.config/logs"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $SCRIPT_NAME: $1" >> "$LOG_FILE"
}

log "--- Script started ---"

# Pin/unpin the currently‑focused window on the left edge.

PIN_W=400                             # sidebar width in px

log "Getting window ID..."
win_id=$(yabai -m query --windows --window | jq '.id')
log "Window ID: $win_id"

log "Getting floating status..."
is_float=$(yabai -m query --windows --window | jq -r '.floating')
log "Floating status: $is_float"

if [[ "$is_float" == "off" ]]; then
  log "Window is not floating. Pinning it..."
  # --- pin it ---
  log "Executing: yabai -m window $win_id --toggle float"
  yabai -m window $win_id --toggle float                    # unmanaged now
  log "Executing: yabai -m window $win_id --move abs:0:0"
  yabai -m window $win_id --move   abs:0:0                  # hug left edge
  log "Executing: yabai -m window $win_id --resize abs:$PIN_W:0"
  yabai -m window $win_id --resize abs:$PIN_W:0             # full height, fixed width
  log "Executing: yabai -m space --padding abs:0:0:$PIN_W:0"
  yabai -m space  --padding abs:0:0:$PIN_W:0                # shrink BSP grid
  log "Window pinned."
else
  log "Window is floating. Un-pinning it..."
  # --- un‑pin it ---
  log "Executing: yabai -m window $win_id --toggle float"
  yabai -m window $win_id --toggle float
  log "Executing: yabai -m space --padding abs:0:0:0:0"
  yabai -m space  --padding abs:0:0:0:0                     # restore full width
  log "Window un-pinned."
fi

log "--- Script finished ---"
