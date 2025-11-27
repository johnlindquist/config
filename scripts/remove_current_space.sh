#!/usr/bin/env bash
# ---------- remove_current_space.sh ----------
# Destroys the current yabai space.

# Script setup
SCRIPT_NAME="remove_current_space.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# Function to log current state
log_state() {
    local type="$1"
    local space_count=$($y -m query --spaces --display 2>/dev/null | $jq 'length' 2>/dev/null || echo "unknown")
    local current_space=$($y -m query --spaces --space 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "unknown")
    local display_id=$($y -m query --displays --display 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "CurrentSpace: $current_space, SpaceCount: $space_count, Display: $display_id"
}

# Log state before action
log_state "BEFORE_STATE"

# 1. Get Current Space Index
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying current space index..."
current_space_index=$($y -m query --spaces --space | $jq '.index')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current space index: $current_space_index"

if [[ -z "$current_space_index" || "$current_space_index" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get current space index"
    echo "Error: Could not determine current space." >&2
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no space index"
    exit 1
fi

# 2. Attempt to destroy the current space
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to destroy space $current_space_index"
if $y -m space --destroy "$current_space_index" 2>&1 | while read line; do
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Yabai output: $line"
done; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully destroyed space $current_space_index"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "Failed to destroy space $current_space_index (might be last space on display)"
fi

# Yabai will prevent destroying the last space on a display automatically.
# The command might print an error to stderr if it fails, which will be logged if DEBUG=true.
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Destroy command executed for space $current_space_index"

# Log state after action
log_state "AFTER_STATE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 