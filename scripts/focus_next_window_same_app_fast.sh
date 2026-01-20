#!/usr/bin/env bash
# ---------- focus_next_window_same_app_fast.sh ----------
# Fast version - cycles to next window of same app

YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"

# Get current window info in one query
CURRENT=$($YABAI -m query --windows --window 2>/dev/null)
[[ -z "$CURRENT" || "$CURRENT" == "null" ]] && exit 1

CURRENT_ID=$(echo "$CURRENT" | $JQ -r '.id')
CURRENT_APP=$(echo "$CURRENT" | $JQ -r '.app')

# Get all windows of same app and find next one in single jq call
NEXT_ID=$($YABAI -m query --windows 2>/dev/null | $JQ -r --arg app "$CURRENT_APP" --arg id "$CURRENT_ID" '
  [.[] | select(.app == $app and .["is-minimized"] == false)] | sort_by(.id) |
  if length <= 1 then empty
  else
    (to_entries | .[] | select(.value.id == ($id | tonumber)) | .key) as $idx |
    .[(($idx + 1) % length)].id
  end
')

[[ -n "$NEXT_ID" ]] && $YABAI -m window --focus "$NEXT_ID" 2>/dev/null
