#!/usr/bin/env bash
# ---------- remove_empty_spaces_current_display.sh ----------
# Finds and destroys empty spaces on the current display.

# Script setup
SCRIPT_NAME="remove_empty_spaces_current_display.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# --- Config ------------------------------------------------
YABAI=/opt/homebrew/bin/yabai                 # tweak if yabai lives elsewhere
JQ=/opt/homebrew/bin/jq

# Function to log current state
log_state() {
    local type="$1"
    local space_count=$("$YABAI" -m query --spaces --display 2>/dev/null | "$JQ" 'length' 2>/dev/null || echo "unknown")
    local empty_count=$("$YABAI" -m query --spaces --display 2>/dev/null | "$JQ" 'map(select(.windows | length == 0)) | length' 2>/dev/null || echo "unknown")
    local display_id=$("$YABAI" -m query --displays --display 2>/dev/null | "$JQ" -r '.index' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "Display: $display_id, SpaceCount: $space_count, EmptySpaces: $empty_count"
}

# Log state before action
log_state "BEFORE_STATE"

# Get current display ID
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Getting current display ID..."
current_display=$("$YABAI" -m query --displays --display | "$JQ" '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current display: $current_display"

# --- Query spaces on current display --------------------------------
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying yabai for spaces on display $current_display..."
spaces_json=$("$YABAI" -m query --spaces --display)
if [[ -z "$spaces_json" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No space data returned"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no space data"
  exit 1
fi

# --- Build list of empty spaces on current display --------
empty_specs=$(
  echo "$spaces_json" | "$JQ" -r '
    map(select(.windows | length == 0) 
        | .index) 
    | reverse                          # destroy highest indices first
    | .[]'
)
if [[ -z "$empty_specs" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "No empty spaces found on display $current_display"
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished - no empty spaces"
  exit 0
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Empty spaces detected: $(echo $empty_specs | tr '\n' ' ')"

# --- Destroy, skipping any "last space" errors ------------
destroyed_count=0
for index in $empty_specs; do
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to destroy space $index on display $current_display"
  if "$YABAI" -m space --destroy "$index" 2>&1 | while read line; do
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Yabai output: $line"
  done; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully destroyed space $index"
    ((destroyed_count++))
  else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Cannot destroy space $index (likely last space on display)"
  fi
done

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Destroyed $destroyed_count empty spaces on display $current_display"

# Log state after action
log_state "AFTER_STATE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
