#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="debug_mouse_display.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"
CLICLICK_PATH="/opt/homebrew/bin/cliclick"

# Log action
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Debugging mouse position and corresponding display."

# 1. Get Mouse Position
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Getting current mouse coordinates via cliclick."
coords=$($CLICLICK_PATH p:.)
exit_code_cliclick=$?
if [[ $exit_code_cliclick -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "cliclick command failed (Exit code: $exit_code_cliclick). Mouse coordinates might be inaccurate."
fi
mouse_x=$(echo "$coords" | cut -d',' -f1 | cut -d'.' -f1)
mouse_y=$(echo "$coords" | cut -d',' -f2 | cut -d'.' -f1)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Mouse coordinates: X=$mouse_x, Y=$mouse_y"

# 2. Get Displays Info
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Querying all displays via yabai."
displays_json=$($YABAI_PATH -m query --displays)
exit_code_yabai=$?
if [[ $exit_code_yabai -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "yabai query displays failed (Exit code: $exit_code_yabai). Aborting."
    exit 1
fi
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "All Displays JSON:\n$(echo "$displays_json" | $JQ_PATH '.')"

# 3. Find Display Under Mouse
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Determining which display contains the mouse coordinates."
target_display_json=$(echo "$displays_json" | $JQ_PATH --argjson mx "$mouse_x" --argjson my "$mouse_y" '
  map(select(
    .frame.x <= $mx and $mx < (.frame.x + .frame.w) and
    .frame.y <= $my and $my < (.frame.y + .frame.h)
  )) | .[0] // empty
')

if [[ -z "$target_display_json" || "$target_display_json" == "null" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "WARN" "No display found containing mouse coordinates ($mouse_x, $mouse_y)."
    echo "[WARN] No display found containing mouse coordinates ($mouse_x, $mouse_y). Check coordinates and display frames."
else
    display_id=$(echo "$target_display_json" | $JQ_PATH -r '.id')
    display_index=$(echo "$target_display_json" | $JQ_PATH -r '.index')
    display_uuid=$(echo "$target_display_json" | $JQ_PATH -r '.uuid')
    display_frame=$(echo "$target_display_json" | $JQ_PATH -c '.frame')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "RESULT" "Mouse is on Display ID: $display_id, Index: $display_index, UUID: $display_uuid, Frame: $display_frame"
    # Also print to stdout for immediate feedback
    echo "[RESULT] Mouse is on Display ID: $display_id, Index: $display_index, UUID: $display_uuid, Frame: $display_frame"
fi

# Log script end
final_exit_code=$([[ $exit_code_cliclick -ne 0 || $exit_code_yabai -ne 0 ]] && echo 1 || echo 0)
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $final_exit_code."

exit $final_exit_code 