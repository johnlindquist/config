#!/bin/bash

# Script to move the focused window to the previous "column" to the left
# by focusing west and then swapping with the new focused window ID.

echo "Attempting to move focused window to the previous column (west)..."
LOG_FILE=~/yabai_move_log.txt
echo "$(date): Starting move west..." >> $LOG_FILE

# Get focused window ID
FOCUSED_WINDOW_ID=$(yabai -m query --windows --window | jq -r '.id')

if [ -z "$FOCUSED_WINDOW_ID" ] || [ "$FOCUSED_WINDOW_ID" == "null" ]; then
  echo "Error: No focused window found." | tee -a $LOG_FILE
  exit 1
fi
echo "Initial focused window ID: $FOCUSED_WINDOW_ID" >> $LOG_FILE

# Attempt to focus the window to the west
yabai -m window --focus west

# Check if focus changed
NEW_FOCUSED_WINDOW_ID=$(yabai -m query --windows --window | jq -r '.id')
echo "Window ID after attempting focus west: $NEW_FOCUSED_WINDOW_ID" >> $LOG_FILE

if [ "$FOCUSED_WINDOW_ID" == "$NEW_FOCUSED_WINDOW_ID" ]; then
  echo "Focus did not change. Window might be the leftmost or focus failed." | tee -a $LOG_FILE
  exit 0
fi

if [ -z "$NEW_FOCUSED_WINDOW_ID" ] || [ "$NEW_FOCUSED_WINDOW_ID" == "null" ]; then
  echo "Error: Failed to get new focused window ID after focus west." | tee -a $LOG_FILE
  # Attempt to focus back - best effort
  yabai -m window "$FOCUSED_WINDOW_ID" --focus
  exit 1
fi

# Swap the original window with the newly focused (western) window
echo "Swapping original window $FOCUSED_WINDOW_ID with western window $NEW_FOCUSED_WINDOW_ID" >> $LOG_FILE
yabai -m window "$FOCUSED_WINDOW_ID" --swap "$NEW_FOCUSED_WINDOW_ID"

if [ $? -eq 0 ]; then
  echo "Successfully swapped $FOCUSED_WINDOW_ID with $NEW_FOCUSED_WINDOW_ID." | tee -a $LOG_FILE
  # Focus back on the original window (which is now in the western position)
  yabai -m window "$FOCUSED_WINDOW_ID" --focus
  echo "Refocused original window ID $FOCUSED_WINDOW_ID." >> $LOG_FILE
else
  echo "Error: Failed to swap windows $FOCUSED_WINDOW_ID and $NEW_FOCUSED_WINDOW_ID." | tee -a $LOG_FILE
  # Attempt to focus back if swap failed
  yabai -m window "$FOCUSED_WINDOW_ID" --focus
  exit 1
fi

echo "Script finished." >> $LOG_FILE
exit 0 