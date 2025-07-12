#!/bin/bash

# Centralized logging helper for Yabai scripts

LOG_FILE_DIR="$HOME/.cache"
LOG_FILE="$LOG_FILE_DIR/yabai_script_log.log"
SCRIPT_NAME="$1"
LOG_TYPE="$2"
MESSAGE="$3"

# Ensure the log directory exists
mkdir -p "$LOG_FILE_DIR"

# ---- Log Rotation (prevent infinite growth) ----
# Rotate the log file when it exceeds MAX_LINES lines.
MAX_LINES=10000  # adjust as needed

# If the main log exists and is too big, rotate it.
if [[ -f "$LOG_FILE" ]]; then
  line_count=$(wc -l < "$LOG_FILE")
  if [[ "$line_count" -ge "$MAX_LINES" ]]; then
    # Remove previous backup if it exists
    [[ -f "${LOG_FILE}.old" ]] && rm "${LOG_FILE}.old"
    # Rotate current log to .old and start fresh
    mv "$LOG_FILE" "${LOG_FILE}.old"
    # Create a new empty log file with same permissions
    touch "$LOG_FILE"
  fi
fi

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Format and append log message
echo "[$TIMESTAMP] [$SCRIPT_NAME] [$LOG_TYPE] $MESSAGE" >> "$LOG_FILE"

exit 0