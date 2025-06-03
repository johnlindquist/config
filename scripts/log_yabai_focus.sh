#!/bin/bash

# Script to log the focused yabai window ID for recency tracking.

LOG_FILE="$HOME/.cache/yabai_focus_history.log"
MAX_HISTORY=20 # Keep track of the last 20 focused windows
TMP_LOG_FILE="${LOG_FILE}.tmp.$$" # Temporary file for atomic write

# Ensure the cache directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Check if the YABAI_WINDOW_ID environment variable is set (provided by the signal)
if [[ -z "$YABAI_WINDOW_ID" ]]; then
  # For testing or manual execution, get the current focused window ID
  CURRENT_FOCUSED_ID=$(/opt/homebrew/bin/yabai -m query --windows --window | /opt/homebrew/bin/jq -r '.id')
  # Validate the manually fetched ID
  if [[ -z "$CURRENT_FOCUSED_ID" || "$CURRENT_FOCUSED_ID" == "null" ]]; then
    rm -f "$TMP_LOG_FILE" # Clean up temp file on error
    exit 1 # Exit if no valid ID found
  fi
  WINDOW_ID="$CURRENT_FOCUSED_ID"
else
  WINDOW_ID="$YABAI_WINDOW_ID"
fi

# Ensure WINDOW_ID is not empty or null before proceeding
if [[ -z "$WINDOW_ID" || "$WINDOW_ID" == "null" ]]; then
  rm -f "$TMP_LOG_FILE" # Clean up temp file on error
  exit 1 # Exit if ID is invalid
fi

history=()
if [[ -f "$LOG_FILE" ]]; then
  # Read line by line using while read
  while IFS= read -r line || [[ -n "$line" ]]; do
      # Trim whitespace (optional, but good practice)
      line_trimmed=$(echo "$line" | xargs)
      if [[ -n "$line_trimmed" ]]; then # Add only non-empty lines
          history+=("$line_trimmed")
      fi
  done < "$LOG_FILE"
else
  # history array is already initialized empty
  : # No action needed if file doesn't exist
fi

# Remove the current window ID if it already exists in the history
new_history=()
for id in "${history[@]}"; do
  # Trim whitespace just in case and compare
  id_trimmed=$(echo "$id" | xargs) # Trim whitespace
  if [[ -n "$id_trimmed" && "$id_trimmed" != "$WINDOW_ID" ]]; then # Ensure ID is not empty after trimming
    new_history+=("$id_trimmed")
  fi
done

# Prepend the new window ID
updated_history=("$WINDOW_ID" "${new_history[@]}")

# Trim the history to MAX_HISTORY entries
if [[ ${#updated_history[@]} -gt $MAX_HISTORY ]]; then
  trimmed_history=("${updated_history[@]:0:$MAX_HISTORY}")
else
  trimmed_history=("${updated_history[@]}")
fi

# Write the updated history to the TEMPORARY file
printf "%s\n" "${trimmed_history[@]}" > "$TMP_LOG_FILE"
if [[ $? -ne 0 ]]; then
    rm -f "$TMP_LOG_FILE" # Clean up temp file on error
    exit 1
fi

# Atomically rename the temporary file to the target log file
mv "$TMP_LOG_FILE" "$LOG_FILE"
if [[ $? -ne 0 ]]; then
    rm -f "$TMP_LOG_FILE" # Clean up temp file on error
    exit 1
fi

exit 0 