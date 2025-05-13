#!/bin/bash

# Add logging helper path
LOGGER_SCRIPT_PATH="$(dirname "$0")/log_helper.sh"
SCRIPT_NAME="log_yabai_focus.sh"

# Log script start (Note: This runs continuously due to `yabai -m signal`)
# We log the initial start, but subsequent logs come from the loop
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Daemon script started. Listening for Yabai signals."

# --- Dependencies ---
YABAI_PATH="/opt/homebrew/bin/yabai"
JQ_PATH="/opt/homebrew/bin/jq"

# Ensure log file directory exists (handled by log_helper.sh, but good practice)
mkdir -p "$HOME/.cache"

# --- Signal Handling Loop ---
# Listen for specific yabai signals related to focus changes
# Add listeners individually

ERRORS=0

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding signal listener for: window_focused"
$YABAI_PATH -m signal --add event=window_focused action="$LOGGER_SCRIPT_PATH $SCRIPT_NAME YABAI_EVENT WindowFocused ID=\\"$YABAI_WINDOW_ID\\"" label="central_script_logger_wf"
if [[ $? -ne 0 ]]; then ERRORS=$((ERRORS + 1)); "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to add window_focused signal."; fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding signal listener for: display_changed"
$YABAI_PATH -m signal --add event=display_changed action="$LOGGER_SCRIPT_PATH $SCRIPT_NAME YABAI_EVENT DisplayChanged ID=\\"$YABAI_DISPLAY_ID\\"" label="central_script_logger_dc"
if [[ $? -ne 0 ]]; then ERRORS=$((ERRORS + 1)); "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to add display_changed signal."; fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding signal listener for: space_changed"
$YABAI_PATH -m signal --add event=space_changed action="$LOGGER_SCRIPT_PATH $SCRIPT_NAME YABAI_EVENT SpaceChanged ID=\\"$YABAI_SPACE_ID\\"" label="central_script_logger_sc"
if [[ $? -ne 0 ]]; then ERRORS=$((ERRORS + 1)); "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to add space_changed signal."; fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding signal listener for: application_activated"
$YABAI_PATH -m signal --add event=application_activated action="$LOGGER_SCRIPT_PATH $SCRIPT_NAME YABAI_EVENT AppActivated App=\\"$YABAI_PROCESS_NAME\\" PID=\\"$YABAI_PROCESS_ID\\"" label="central_script_logger_aa"
if [[ $? -ne 0 ]]; then ERRORS=$((ERRORS + 1)); "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to add application_activated signal."; fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Adding signal listener for: window_title_changed"
$YABAI_PATH -m signal --add event=window_title_changed action="$LOGGER_SCRIPT_PATH $SCRIPT_NAME YABAI_EVENT WindowTitleChanged ID=\\"$YABAI_WINDOW_ID\\"" label="central_script_logger_wtc"
if [[ $? -ne 0 ]]; then ERRORS=$((ERRORS + 1)); "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to add window_title_changed signal."; fi

EXIT_CODE=$ERRORS

if [[ $EXIT_CODE -ne 0 ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Failed to add one or more Yabai signals ($ERRORS errors)."
    exit $EXIT_CODE
else
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Successfully added all Yabai signal listeners."
    # Add a message indicating it will keep running
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Script is now running in the background (implicitly via signal handling) to log Yabai events."
    # Typically, a script listening for signals doesn't exit here,
    # but relies on the yabai process managing the signals.
    # For clarity in logging, we log completion of setup.
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Signal setup finished. Logging will occur on Yabai events."
    exit 0 # Exit setup script successfully
fi

# Note: The actual logging now happens directly via the `action` in `yabai -m signal` calls.
# This script primarily sets up those listeners. 