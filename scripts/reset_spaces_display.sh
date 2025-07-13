#!/bin/bash

# Comprehensive script to fix Mission Control display issues
SCRIPT_NAME="reset_spaces_display"

echo "Fixing Mission Control space display issues..."

# 1. Reset Mission Control cache
echo "Resetting Mission Control cache..."
rm -f ~/Library/Preferences/com.apple.spaces.plist 2>/dev/null
rm -f ~/Library/Preferences/com.apple.dock.plist 2>/dev/null

# 2. Kill relevant processes
echo "Restarting system UI processes..."
killall Dock
killall "Mission Control" 2>/dev/null
killall ControlCenter 2>/dev/null

# Wait for processes to restart
sleep 3

# 3. Reset space names/labels
echo "Resetting space labels..."
/opt/homebrew/bin/yabai -m query --spaces | /opt/homebrew/bin/jq -r '.[].index' | while read -r idx; do
    /opt/homebrew/bin/yabai -m space "$idx" --label "Desktop $idx"
    sleep 0.1
done

# 4. Force Mission Control to rebuild its cache
echo "Forcing Mission Control to rebuild..."
# Open and close Mission Control programmatically
osascript -e 'tell application "Mission Control" to launch'
sleep 1
osascript -e 'tell application "System Events" to key code 53' # ESC to close

# 5. Restart yabai
echo "Restarting yabai..."
yabai --restart-service

echo "Fix complete. Please check Mission Control now."
echo "If the issue persists, you may need to log out and back in."