#!/bin/bash

# Script to detach the active Chrome tab into a new window
SCRIPT_NAME="detach_chrome_tab"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Detaching active Chrome tab to new window"

# AppleScript to detach the active tab
osascript -e '
tell application "Google Chrome"
    if (count of windows) > 0 then
        -- Get the active tab from the front window
        set activeTab to active tab of front window
        set tabURL to URL of activeTab
        set tabTitle to title of activeTab
        
        -- Store the current window
        set currentWindow to front window
        
        -- Check if this is the only tab in the window
        if (count of tabs of currentWindow) > 1 then
            -- Close the active tab
            close activeTab
            
            -- Create a new window with the saved URL
            make new window
            set URL of active tab of front window to tabURL
            
            return "Tab detached: " & tabTitle
        else
            -- If only one tab, just keep the window as is
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