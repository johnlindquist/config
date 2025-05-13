#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="list_spaces_and_windows.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Log action
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Querying and listing detailed space and window information."

# Query spaces and windows
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying spaces..."
spaces_json=$($YABAI_PATH -m query --spaces)
spaces_exit=$?
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying windows..."
windows_json=$($YABAI_PATH -m query --windows)
windows_exit=$?

if [[ $spaces_exit -ne 0 || $windows_exit -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to query yabai. Spaces exit: $spaces_exit, Windows exit: $windows_exit. Aborting."
    exit 1
fi

# Log the raw data
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DATA" "Raw Spaces JSON:\n$spaces_json"
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DATA" "Raw Windows JSON:\n$windows_json"

# Process and format output (also print to stdout for direct use)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Processing and formatting data for output."

output=$($JQ_PATH -n --argjson spaces "$spaces_json" --argjson windows "$windows_json" \
'($windows | group_by(.space) | map({(.[0].space | tostring): .}) | add) as $windows_by_space
 |
 $spaces | map(
   . as $space |
   "Space \(.index) (ID: \(.id), UUID: \(.uuid), Display: \(.display), Type: \(.type))" +
   (if .["has-focus"] then " [FOCUSED]" else "" end) +
   (if .["is-visible"] then " [VISIBLE]" else "" end) +
   "\n" +
   (
     ($windows_by_space[($space.index | tostring)] // []) | map(
       "  Window \(.id): \(.app) - \"\(.title)\"" +
       (if .["has-focus"] then " [FOCUSED]" else "" end) +
       (if .["is-floating"] then " [FLOATING]" else "" end) +
       (if .["is-sticky"] then " [STICKY]" else "" end) +
       (if .["is-minimized"] then " [MINIMIZED]" else "" end) +
       (if .["is-hidden"] then " [HIDDEN]" else "" end) +
       " (Frame: \(.frame.x), \(.frame.y), \(.frame.w), \(.frame.h))"
     ) | join("\n")
   )
 ) | join("\n---\n")'
)

# Log the formatted output
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "RESULT" "Formatted Output:\n$output"

# Print formatted output to stdout
echo -e "$output"

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished successfully."

exit 0 