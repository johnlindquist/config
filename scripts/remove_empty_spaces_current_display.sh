#!/usr/bin/env bash
# ---------- remove_empty_spaces_all_displays.sh ----------
# Finds and destroys *all* empty spaces on *all* displays.

# --- Config ------------------------------------------------
DEBUG=false                                   # flip to true for verbose logs
YABAI=/opt/homebrew/bin/yabai                 # tweak if yabai lives elsewhere
JQ=/opt/homebrew/bin/jq
LOG_FILE="$HOME/.config/logs/remove_empty_spaces_all_displays.log"

# --- Helper ------------------------------------------------
log() {
  [[ "$DEBUG" == "true" ]] && {
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%(%Y-%m-%d %H:%M:%S)T - %s\n' -1 "$*" >> "$LOG_FILE"
  }
}
[[ "$DEBUG" == "true" ]] && { exec 2>>"$LOG_FILE"; log "--- Script Start ---"; }

# --- Query all spaces once --------------------------------
log "Querying yabai for all spaces..."
spaces_json=$("$YABAI" -m query --spaces)              # returns full JSON :contentReference[oaicite:1]{index=1}
if [[ -z "$spaces_json" ]]; then
  log "Error: No space data returned."
  exit 1
fi

# --- Build list of empty spaces grouped by display --------
empty_specs=$(
  echo "$spaces_json" | "$JQ" -r '
    map(select(.windows | length == 0) 
        | {display: .display, index: .index}) 
    | sort_by(.display, .index)        # keep stable order
    | reverse                          # destroy highest indices first
    | .[] | "\(.display):\(.index)"'
)
if [[ -z "$empty_specs" ]]; then
  log "No empty spaces found on any display."
  exit 0
fi
log "Empty spaces detected: $empty_specs"

# --- Destroy, skipping any “last space” errors ------------
for spec in $empty_specs; do
  display=${spec%%:*}
  index=${spec#*:}
  log "Attempting to destroy space $index on display $display..."
  "$YABAI" -m space --destroy "$index" && \
    log "Destroyed space $index." || \
    log "Skip: yabai denied destroying space $index (likely last space)."
done

log "--- Script End ---"
