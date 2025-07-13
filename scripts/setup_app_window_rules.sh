#!/bin/bash

# Script to set up yabai rules for specific app window placement
SCRIPT_NAME="setup_app_window_rules"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log the start of the script
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Setting up app window placement rules"

# Yabai binary path
YABAI="/opt/homebrew/bin/yabai"

# First, remove any existing rules for these apps
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Removing existing rules for target apps"
$YABAI -m rule --remove "Pieces" 2>/dev/null || true
$YABAI -m rule --remove "Zed" 2>/dev/null || true
$YABAI -m rule --remove "Slack" 2>/dev/null || true
$YABAI -m rule --remove "Messages" 2>/dev/null || true

# Add rules for each app
# Note: Yabai rules apply when windows are created, not to existing windows

# Pieces - Display 4, Space 12, Left side
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding rule for Pieces"
$YABAI -m rule --add app="^Pieces$" \
    display=4 \
    space=12 \
    manage=on \
    grid=1:2:0:0:1:1

# Zed - Display 4, Space 12, Right side
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding rule for Zed"
$YABAI -m rule --add app="^Zed$" \
    display=4 \
    space=12 \
    manage=on \
    grid=1:2:1:0:1:1

# Slack - Display 4, Space 11, Left side
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding rule for Slack"
$YABAI -m rule --add app="^Slack$" \
    display=4 \
    space=11 \
    manage=on \
    grid=1:2:0:0:1:1

# Messages - Display 4, Space 11, Right side
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding rule for Messages"
$YABAI -m rule --add app="^Messages$" \
    display=4 \
    space=11 \
    manage=on \
    grid=1:2:1:0:1:1

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Window placement rules configured"

# Print current rules for verification
echo "Current rules for target apps:"
$YABAI -m rule --list | grep -E "Pieces|Zed|Slack|Messages" || echo "No rules found"

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"