#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="restart_yabai.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started."

# Log action
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Attempting to restart yabai service via brew."

brew services restart yabai
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "brew services restart yabai failed with exit code $EXIT_CODE."
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "brew services restart yabai command executed successfully (Exit code: $EXIT_CODE). Check brew logs for details."
fi

# Log script end
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script finished with exit code $EXIT_CODE."

exit $EXIT_CODE 