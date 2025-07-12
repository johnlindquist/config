#!/usr/bin/env bash
# -------- launch_focus_app.sh --------
# Activates the given macOS application and focuses its most-recent window via yabai.

# --- Usage & Arg Check ------------------------------------------------------
APP="$1"
if [[ -z "$APP" ]]; then
  echo "Usage: $0 <App Name>" >&2
  exit 1
fi

# --- Paths ------------------------------------------------------------------
OSA="/usr/bin/osascript"
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# --- Activate App -----------------------------------------------------------
$OSA -e "tell application \"$APP\" to activate"

# brief pause to let windows register
sleep 0.15

# --- Find Most-Recent Window for App ---------------------------------------
wid=$($YABAI -m query --windows | $JQ -r --arg AP "$APP" 'map(select(.app == $AP and ."has-focus")) | .[0].id // empty')

# --- Focus Window/Space -----------------------------------------------------
if [[ -n "$wid" ]]; then
  $YABAI -m window "$wid" --focus
fi

exit 0 