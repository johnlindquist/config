#!/usr/bin/env bash
# -------- launch_focus_app_fast.sh --------
# Fast version - minimal overhead for keyboard shortcuts
# Activates app or cycles windows if already focused

APP="$1"
[[ -z "$APP" ]] && exit 1

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
SCRIPT_DIR="$(dirname "$0")"

# Get current focused app in one query
CURRENT_APP=$($YABAI -m query --windows --window 2>/dev/null | $JQ -r '.app // empty' 2>/dev/null)

if [[ "$CURRENT_APP" == "$APP" ]]; then
  # Already focused - cycle to next window
  exec "$SCRIPT_DIR/focus_next_window_same_app_fast.sh"
else
  # Activate app
  /usr/bin/osascript -e "tell application \"$APP\" to activate" &>/dev/null

  # Focus first non-minimized window (no sleep - let yabai handle it)
  wid=$($YABAI -m query --windows 2>/dev/null | $JQ -r --arg AP "$APP" \
    '[.[] | select(.app == $AP and .["is-minimized"] == false)] | .[0].id // empty')
  [[ -n "$wid" ]] && $YABAI -m window "$wid" --focus 2>/dev/null
fi
