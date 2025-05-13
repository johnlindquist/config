#!/usr/bin/env bash
# ---------- fix_floats.sh ----------
# Re-tiles a floating window or drops an always-on-top window to normal layer,
# then balances the current space.  Designed to be called from yabai signals
# or a Karabiner hotkey.

# --- Config ------------------------------------------------
DEBUG=true
YABAI="/opt/homebrew/bin/yabai"
JQ="/opt/homebrew/bin/jq"
SCRIPT_NAME="fix_floats.sh"
LOG_HELPER_PATH="$HOME/.config/scripts/log_helper.sh" # Absolute path to log_helper
# LOG_FILE_FIX_FLOATS="$HOME/.config/logs/fix_floats_dedicated.log" # Remove dedicated log file

# --- Logging (Reinstating log_helper.sh) ------------------
log_msg() {
  local log_type="$1"
  local message="$2"
  if [[ "$DEBUG" == "true" ]]; then
    if [[ -f "$LOG_HELPER_PATH" && -x "$LOG_HELPER_PATH" ]]; then
      "$LOG_HELPER_PATH" "$SCRIPT_NAME" "$log_type" "$message"
    else
      # Fallback echo if helper is not found or not executable
      local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
      echo "[$timestamp] [$SCRIPT_NAME] [LOG_HELPER_ERROR] Path '$LOG_HELPER_PATH' not found or not executable. Message: $message"
    fi
  fi
}

log_msg "INFO" "--- Script Start ---"

# --- Safety checks -----------------------------------------
command -v "$YABAI" >/dev/null 2>&1 || { log_msg "ERROR" "yabai not found (path: $YABAI)"; echo "yabai not found"; exit 1; }
command -v "$JQ"    >/dev/null 2>&1 || { log_msg "ERROR" "jq not found (path: $JQ)";    echo "jq not found";    exit 1; }

# --- Grab focused window info ------------------------------
log_msg "DEBUG" "Attempting: $YABAI -m query --windows --window"
info=$("$YABAI" -m query --windows --window 2>&1) # Capture stderr from yabai too
exit_code=$?
log_msg "DEBUG" "yabai query exit_code: $exit_code"
log_msg "DEBUG" "yabai query output (info): $info"

if [[ $exit_code -ne 0 || -z "$info" || "$info" == "could not retrieve window details."* ]]; then
  log_msg "ERROR" "yabai query failed or returned specific error. Exit code: $exit_code. Output: $info"
  echo "could not retrieve window details."
  exit 1
fi

log_msg "DEBUG" "Raw yabai info (pre-jq): $info"
is_float=$("$JQ" -r '."is-floating"' <<<"$info")
sub_layer=$("$JQ" -r '."sub-layer"'  <<<"$info")
win_id=$("$JQ" -r '.id' <<<"$info")

if [[ -z "$win_id" || "$win_id" == "null" ]]; then
    log_msg "ERROR" "Failed to parse window id with jq (win_id is '$win_id'). Info was: $info"
    echo "could not parse window details from yabai output."
    exit 1
fi

log_msg "INFO" "Processing window $win_id: float=$is_float, layer=$sub_layer"

# --- Fix #1: pull floaters back into BSP -------------------
if [[ "$is_float" == "true" ]]; then
  log_msg "INFO" "Window $win_id is floating. Toggling float."
  "$YABAI" -m window "$win_id" --toggle float
fi

# --- Fix #2: reset abnormal layer --------------------------
if [[ -n "$sub_layer" && "$sub_layer" != "auto" ]]; then
  log_msg "INFO" "Window $win_id has abnormal layer ('$sub_layer'). Resetting to auto."
  "$YABAI" -m window "$win_id" --sub-layer auto
fi

# --- Clean-up: rebalance splits ----------------------------
log_msg "INFO" "Balancing current space."
"$YABAI" -m space --balance

log_msg "INFO" "--- Script End ---"
exit 0
