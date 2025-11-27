#!/bin/bash
# Launch WezTerm with a command, always new window, auto-focus

CMD="$1"
WEZTERM="/Applications/WezTerm.app/Contents/MacOS/wezterm"
SOCKET="$HOME/.local/share/wezterm/default-org.wezfurlong.wezterm"

# Check if WezTerm GUI is running
if pgrep -x "wezterm-gui" > /dev/null; then
  # Already running - spawn shell first, then send command to it
  osascript -e 'tell application "WezTerm" to activate'
  PANE_ID=$(WEZTERM_UNIX_SOCKET="$SOCKET" "$WEZTERM" cli spawn --new-window)
  # Send the command followed by Enter
  printf '%s\n' "$CMD" | WEZTERM_UNIX_SOCKET="$SOCKET" "$WEZTERM" cli send-text --no-paste --pane-id "$PANE_ID"
else
  # Not running - launch fresh, then send command after it's ready
  open -a WezTerm
  sleep 0.5  # Wait for WezTerm to start and create socket
  PANE_ID=$(WEZTERM_UNIX_SOCKET="$SOCKET" "$WEZTERM" cli list --format json 2>/dev/null | grep -o '"pane_id":[0-9]*' | head -1 | cut -d: -f2)
  if [ -n "$PANE_ID" ]; then
    printf '%s\n' "$CMD" | WEZTERM_UNIX_SOCKET="$SOCKET" "$WEZTERM" cli send-text --no-paste --pane-id "$PANE_ID"
  fi
fi
