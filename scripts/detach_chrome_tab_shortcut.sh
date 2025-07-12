#!/bin/bash

# Script to detach the active Chrome tab using keyboard shortcuts
SCRIPT_NAME="detach_chrome_tab_shortcut"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Detaching active Chrome tab using shortcuts"

# AppleScript to detach tab using keyboard shortcuts
osascript -e '
tell application "Google Chrome"
    if (count of windows) > 0 then
        activate
        
        -- Check if there is more than one tab
        if (count of tabs of front window) > 1 then
            -- Get current tab info before moving
            set currentTab to active tab of front window
            set tabURL to URL of currentTab
            set tabTitle to title of currentTab
            
            tell application "System Events"
                tell process "Google Chrome"
                    -- Move tab to new window using Shift+Cmd+N
                    -- This is a custom shortcut you would need to set up in Chrome
                    -- Alternatively, we can use the menu
                    try
                        -- Use the Tab menu to move to new window
                        click menu item "Move Tab to New Window" of menu "Tab" of menu bar 1
                        delay 0.2
                        return "Tab detached: " & tabTitle
                    on error
                        -- If menu item not found, try alternative approach
                        -- Select all text in address bar
                        keystroke "l" using command down
                        delay 0.1
                        -- Copy URL
                        keystroke "c" using command down
                        delay 0.1
                        -- Close tab
                        keystroke "w" using command down
                        delay 0.1
                        -- New window
                        keystroke "n" using command down
                        delay 0.2
                        -- Paste URL
                        keystroke "v" using command down
                        delay 0.1
                        -- Go to URL
                        keystroke return
                        return "Tab detached (alternative method): " & tabTitle
                    end try
                end tell
            end tell
        else
            return "Only one tab in window, not detaching"
        end if
    else
        return "No Chrome windows open"
    end if
end tell
' 2>&1

RESULT=$?

if [ $RESULT -eq 0 ]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully detached Chrome tab"
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to detach Chrome tab (exit code: $RESULT)"
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"
exit $RESULT