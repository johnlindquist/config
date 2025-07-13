#!/bin/bash

# Safe script to fix Mission Control space display sync
echo "Safely fixing Mission Control space display..."

# 1. Get current space info
echo "Current spaces:"
/opt/homebrew/bin/yabai -m query --spaces | /opt/homebrew/bin/jq -r '.[] | "Space \(.index) on display \(.display): \(.windows | length) windows"'

# 2. Add descriptive labels to all spaces
echo -e "\nAdding labels to spaces..."
/opt/homebrew/bin/yabai -m query --spaces | /opt/homebrew/bin/jq -r '.[] | .index' | while read -r idx; do
    window_count=$(/opt/homebrew/bin/yabai -m query --windows --space "$idx" | /opt/homebrew/bin/jq 'length')
    /opt/homebrew/bin/yabai -m space "$idx" --label "Desktop $idx ($window_count windows)"
done

# 3. Trigger Mission Control refresh without killing Dock
echo -e "\nRefreshing Mission Control..."
# Use AppleScript to open Mission Control
osascript << 'EOF'
tell application "System Events"
    -- Open Mission Control
    key code 160
    delay 0.5
    -- Close Mission Control
    key code 53
end tell
EOF

# 4. Show updated state
echo -e "\nUpdated spaces:"
/opt/homebrew/bin/yabai -m query --spaces | /opt/homebrew/bin/jq -r '.[] | "Space \(.index) [\(.label)]: \(.windows | length) windows"'

echo -e "\nMission Control should now show correct window counts."
echo "If Desktop 1 still shows as empty, try:"
echo "  1. Open Mission Control manually (F3 or swipe up with 3 fingers)"
echo "  2. Click on Desktop 1"
echo "  3. If still broken, run: killall Dock"