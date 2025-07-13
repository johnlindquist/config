#!/bin/bash

# Script to fix Mission Control sync issues with yabai
SCRIPT_NAME="fix_mission_control_sync"

# Use the helper script for logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Fixing Mission Control sync issues"

# Paths
YABAI="/opt/homebrew/bin/yabai"

# Method 1: Restart Dock (which manages Mission Control)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Restarting Dock to refresh Mission Control"
killall Dock

# Wait for Dock to restart
sleep 2

# Method 2: Re-label all spaces to force Mission Control update
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Re-labeling spaces to force update"
$YABAI -m query --spaces | /opt/homebrew/bin/jq -r '.[].index' | while read -r space_index; do
    # Set a temporary label
    $YABAI -m space "$space_index" --label "space_$space_index" 2>/dev/null || true
    # Clear the label
    $YABAI -m space "$space_index" --label "" 2>/dev/null || true
done

# Method 3: Toggle mission-control setting
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Toggling mission-control setting"
current_setting=$($YABAI -m config mouse_follows_focus)
$YABAI -m config mouse_follows_focus on
sleep 0.5
$YABAI -m config mouse_follows_focus off
sleep 0.5
$YABAI -m config mouse_follows_focus "$current_setting"

# Method 4: Create and destroy a dummy space to force refresh
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Creating and destroying dummy space"
$YABAI -m space --create
sleep 0.5
newest_space=$($YABAI -m query --spaces | /opt/homebrew/bin/jq -r 'max_by(.index) | .index')
$YABAI -m space "$newest_space" --destroy

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mission Control sync fix completed"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished"