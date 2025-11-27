#!/usr/bin/env bash
# Pin/unpin the currently‑focused window on the left edge.

# Script setup
SCRIPT_NAME="pin_left.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# Use absolute paths
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

PIN_W=400                             # sidebar width in px

# Function to log current state
log_state() {
    local type="$1"
    local window_id=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r '.id' 2>/dev/null || echo "unknown")
    local floating=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r '.floating' 2>/dev/null || echo "unknown")
    local space_padding=$($YABAI -m query --spaces --space 2>/dev/null | $JQ -r '.padding' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Floating: $floating, SpacePadding: $space_padding"
}

# Log state before action
log_state "BEFORE_STATE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Getting window ID..."
win_id=$($YABAI -m query --windows --window | $JQ '.id')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Window ID: $win_id"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Getting floating status..."
is_float=$($YABAI -m query --windows --window | $JQ -r '.floating')
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Floating status: $is_float"

if [[ "$is_float" == "off" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window is not floating. Pinning it..."
  # --- pin it ---
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Toggling window float: $win_id"
  $YABAI -m window $win_id --toggle float                    # unmanaged now
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window to abs:0:0"
  $YABAI -m window $win_id --move   abs:0:0                  # hug left edge
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Resizing window to width:$PIN_W"
  $YABAI -m window $win_id --resize abs:$PIN_W:0             # full height, fixed width
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Setting space padding to left:$PIN_W"
  $YABAI -m space  --padding abs:0:0:$PIN_W:0                # shrink BSP grid
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window pinned successfully"
else
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window is floating. Un-pinning it..."
  # --- un‑pin it ---
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Toggling window float: $win_id"
  $YABAI -m window $win_id --toggle float
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Resetting space padding to 0"
  $YABAI -m space  --padding abs:0:0:0:0                     # restore full width
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window un-pinned successfully"
fi

# Log state after action
log_state "AFTER_STATE"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
