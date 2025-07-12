#!/bin/bash

# Script to detach the active Chrome tab using native drag functionality
SCRIPT_NAME="detach_chrome_tab_native"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Detaching active Chrome tab using native drag"

# AppleScript to detach the active tab using System Events
osascript -e '
tell application "Google Chrome"
    if (count of windows) > 0 then
        activate
        
        -- Get info about current window and tab
        set currentWindow to front window
        set tabCount to count of tabs of currentWindow
        
        if tabCount > 1 then
            -- Use System Events to drag the tab out
            tell application "System Events"
                tell process "Google Chrome"
                    -- Get the active tab UI element
                    set frontmost to true
                    delay 0.1
                    
                    -- Find and click-drag the active tab
                    try
                        -- Get the tab bar
                        set tabBar to group 1 of toolbar 1 of window 1
                        
                        -- Get the active tab (it has selected attribute)
                        set activeTabs to (buttons of tabBar whose selected is true)
                        
                        if (count of activeTabs) > 0 then
                            set activeTab to item 1 of activeTabs
                            set tabPosition to position of activeTab
                            set tabX to item 1 of tabPosition
                            set tabY to item 2 of tabPosition
                            
                            -- Drag the tab down to detach it
                            tell activeTab
                                perform action "AXPress"
                                delay 0.1
                            end tell
                            
                            -- Simulate dragging down
                            do shell script "cliclick dd:" & tabX & "," & tabY & " du:" & tabX & "," & (tabY + 100)
                            
                            return "Tab detached successfully"
                        else
                            return "Could not find active tab"
                        end if
                    on error errMsg
                        return "Error: " & errMsg
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