#!/bin/bash

# Centralized logging helper for Yabai scripts

LOG_FILE_DIR="$HOME/.cache"
LOG_FILE="$LOG_FILE_DIR/yabai_script_log.log"
SCRIPT_NAME="$1"
LOG_TYPE="$2"
MESSAGE="$3"

# Ensure the log directory exists
mkdir -p "$LOG_FILE_DIR"

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Format and append log message
echo "[$TIMESTAMP] [$SCRIPT_NAME] [$LOG_TYPE] $MESSAGE" >> "$LOG_FILE"

exit 0