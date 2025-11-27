#!/usr/bin/env bash
# -------- launch_focus_app.sh --------
# Activates the given macOS application. If it is already frontmost,
# cycle to the next window of that app (using yabai). Otherwise bring
# the app to front and focus its main window. Re-running the script will
# keep cycling through that app's windows.

# Script setup
SCRIPT_NAME="launch_focus_app.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# --- Usage & Arg Check ------------------------------------------------------
APP="$1"
if [[ -z "$APP" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No app name provided"
  echo "Usage: $0 <App Name>" >&2
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - missing argument"
  exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Launch/focus app with cycling: $APP"

# --- Paths ------------------------------------------------------------------
OSA="/usr/bin/osascript"
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Function to log current state
log_state() {
    local type="$1"
    local window_json
    local window_id="unknown"
    local space_id="unknown"
    local focused_app="unknown"

    window_json=$($YABAI -m query --windows --window 2>/dev/null)
    if [[ -n "$window_json" && "$window_json" != "null" ]]; then
      window_id=$(echo "$window_json" | $JQ -r '.id' 2>/dev/null || echo "unknown")
      focused_app=$(echo "$window_json" | $JQ -r '.app' 2>/dev/null || echo "unknown")
    fi
    space_id=$($YABAI -m query --spaces --space 2>/dev/null | $JQ -r '.index' 2>/dev/null || echo "unknown")

    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Space: $space_id, FocusedApp: $focused_app"
}

# Log state before action
log_state "BEFORE_STATE"

# --- Determine frontmost app ------------------------------------------------
CURRENT_APP=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r '.app // empty' 2>/dev/null)
if [[ -z "$CURRENT_APP" || "$CURRENT_APP" == "null" ]]; then
  CURRENT_APP=$($OSA -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Current frontmost app: ${CURRENT_APP:-unknown}"

# --- If already focused, cycle to next window ------------------------------
if [[ "$CURRENT_APP" == "$APP" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "App is frontmost; cycling to next window"
  "${SCRIPT_DIR}/focus_next_window_same_app.sh"
  cycle_exit=$?
  if [[ $cycle_exit -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Cycling via yabai failed with exit $cycle_exit"
  fi
else
  # --- Otherwise activate app and focus one of its windows ------------------
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Activating app via AppleScript"
  $OSA -e "tell application \"$APP\" to activate" 2>&1 | while read line; do
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "AppleScript output: $line"
  done

  # brief pause to let windows register
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Waiting 0.15s for windows to register"
  sleep 0.15

  # Try to ensure a window of the app is focused (pick first non-minimized)
  wid=$($YABAI -m query --windows 2>/dev/null | $JQ -r --arg AP "$APP" '[.[] | select(.app == $AP and .["is-minimized"] == false)] | .[0].id // empty' 2>/dev/null)
  if [[ -n "$wid" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing window $wid for app $APP"
    $YABAI -m window "$wid" --focus 2>/dev/null
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Focused window $wid for $APP"
  else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARNING" "No non-minimized window found to focus for $APP"
  fi
fi

# Log state after action
log_state "AFTER_STATE"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"

exit 0 
