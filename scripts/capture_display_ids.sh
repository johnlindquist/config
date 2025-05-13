#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="capture_display_ids.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

OUTPUT_FILE="$(dirname "$0")/display_id_mapping.txt"

# Log action
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Querying displays and writing mapping to $OUTPUT_FILE."

# Get display info
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying current display information."
displays_json=$($YABAI_PATH -m query --displays)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to query displays (Exit code: $exit_code). Aborting."
    exit 1
fi

if [[ -z "$displays_json" || "$displays_json" == "null" || "$displays_json" == "[]" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No displays found or failed to parse display JSON. Aborting."
    exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Display query successful. Processing and writing to file."

# Process and write to file
{ 
echo "# Display ID Mapping (Generated: $(date))"
echo "# Format: ID | UUID | INDEX | IS_MAIN | HAS_FOCUS | FRAME (x,y,w,h)"
echo "$displays_json" | $JQ_PATH -r '.[] | "\(.id) | \(.uuid) | \(.index) | \(.["is-native"] and .["is-main"]) | \(.["has-focus"]) | \(.frame.x), \(.frame.y), \(.frame.w), \(.frame.h)"'
} > "$OUTPUT_FILE"
write_exit_code=$?

if [[ $write_exit_code -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to write display mapping to $OUTPUT_FILE (Exit code: $write_exit_code)."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully wrote display mapping to $OUTPUT_FILE."
    # Log the content written
    file_content=$(cat "$OUTPUT_FILE")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "File Content:\n$file_content"
fi

# Log script end
final_exit_code=$([[ $exit_code -ne 0 || $write_exit_code -ne 0 ]] && echo 1 || echo 0)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $final_exit_code."

exit $final_exit_code 