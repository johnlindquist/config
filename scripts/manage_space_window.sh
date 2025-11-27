#!/usr/bin/env bash
# ---------- manage_space_window.sh ----------
# Manages spaces and windows based on the first argument.
# Arguments:
#   space-left:   Focus/create space to the left.
#   space-right:  Focus/create space to the right.
#   window-left:  Move focused window left (create space if needed).
#   window-right: Move focused window right (create space if needed).

# Script setup
SCRIPT_NAME="manage_space_window.sh"
SCRIPT_DIR="$(dirname "$0")"
LOGGER_SCRIPT_PATH="$SCRIPT_DIR/log_helper.sh"

# Log script start
"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "START" "Script execution started"

# --- Argument Handling ---
ACTION="$1"

if [[ -z "$ACTION" ]]; then
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No action specified"
  echo "Error: No action specified. Use one of: space-left, space-right, window-left, window-right" >&2
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - missing argument"
  exit 1
fi

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Requested action: $ACTION"

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# Function to log current state
log_state() {
    local type="$1"
    local window_id=$($y -m query --windows --window 2>/dev/null | $jq -r '.id' 2>/dev/null || echo "unknown")
    local space_id=$($y -m query --spaces --space 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "unknown")
    local display_id=$($y -m query --displays --display 2>/dev/null | $jq -r '.index' 2>/dev/null || echo "unknown")
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "$type" "WindowID: $window_id, Space: $space_id, Display: $display_id"
}

# --- Helper Functions ---
get_focused_window_id() {
  local id
  "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Getting focused window ID..."
  id=$($y -m query --windows --window | $jq '.id')
  if [[ -z "$id" || "$id" == "null" ]]; then
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Could not get focused window ID"
      # Optionally exit or return an error code/empty string
      echo "" # Return empty string on failure
  else
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focused window ID: $id"
      echo "$id"
  fi
}

focus_window() {
  local window_id="$1"
  if [[ -n "$window_id" ]]; then
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Refocusing window $window_id"
    $y -m window --focus "$window_id"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Refocus window command executed"
  fi
}

# --- Main Logic based on Action ---

case "$ACTION" in
  space-left)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Processing space-left action"
    log_state "BEFORE_STATE"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current space index: $cur"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying previous space index..."
    prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index < $cur)) | sort_by(.index) | .[-1].index // "" ')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Previous space index: '$prev'"

    if [[ "$prev" == '""' ]]; then
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected, creating new space"
      $y -m space --create
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Create command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying last space index (new one)..."
      new=$($y -m query --spaces --display | $jq '.[-1].index')
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "New space index: $new"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing new space ($new) temporarily"
      $y -m space --focus "$new"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Temporary focus command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving new space ($new) to position 1"
      $y -m space --move 1
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Move command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space 1"
      $y -m space --focus 1
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focus command executed"
    else
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Neighbour found ('$prev'), focusing"
      $y -m space --focus "$prev"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focus command executed"
    fi
    
    log_state "AFTER_STATE"
    ;;

  space-right)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Processing space-right action"
    log_state "BEFORE_STATE"
    
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current space index: $cur"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying next space index..."
    next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index > $cur)) | sort_by(.index) | .[0].index // "" ')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Next space index: '$next'"

    if [[ "$next" == '""' ]]; then
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected, creating new space"
      $y -m space --create
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Create command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying last space index..."
      last=$($y -m query --spaces --display | $jq '.[-1].index')
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Last space index: $last"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $last"
      $y -m space --focus "$last"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focus command executed"
    else
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Neighbour found ('$next'), focusing"
      $y -m space --focus "$next"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focus command executed"
    fi
    
    log_state "AFTER_STATE"
    ;;

  window-left)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Processing window-left action"
    log_state "BEFORE_STATE"
    
    window_id=$(get_focused_window_id)
    if [[ -z "$window_id" ]]; then 
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No focused window to move"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no window"
      exit 1
    fi

    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current space index: $cur"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying previous space index..."
    prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index < $cur)) | sort_by(.index) | .[-1].index // "" ')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Previous space index: '$prev'"

    target_space=""
    if [[ "$prev" == '""' ]]; then
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected, creating new space"
      $y -m space --create
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Create command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying last space index (new one)..."
      new=$($y -m query --spaces --display | $jq '.[-1].index')
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "New space index: $new"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing new space ($new) temporarily"
      $y -m space --focus "$new"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Temporary focus command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving new space ($new) to position 1"
      $y -m space --move 1
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Move command executed"
      target_space=1
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Target space set to: $target_space"
    else
      target_space="$prev"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Target space set to: $target_space"
    fi

    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space $target_space"
    $y -m window "$window_id" --space "$target_space"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Move command executed"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $target_space"
    $y -m space --focus "$target_space"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focus space command executed"
    focus_window "$window_id"
    
    log_state "AFTER_STATE"
    ;;

  window-right)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Processing window-right action"
    log_state "BEFORE_STATE"
    
    window_id=$(get_focused_window_id)
    if [[ -z "$window_id" ]]; then 
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "No focused window to move"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - no window"
      exit 1
    fi

    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Current space index: $cur"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying next space index..."
    next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index > $cur)) | sort_by(.index) | .[0].index // "" ')
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Next space index: '$next'"

    target_space=""
    if [[ "$next" == '""' ]]; then
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "INFO" "Edge detected, creating new space"
      $y -m space --create
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Create command executed"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Querying last space index..."
      last=$($y -m query --spaces --display | $jq '.[-1].index')
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Last space index: $last"
      target_space="$last"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Target space set to: $target_space"
    else
      target_space="$next"
      "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Target space set to: $target_space"
    fi

    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Moving window $window_id to space $target_space"
    $y -m window "$window_id" --space "$target_space"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Move command executed"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ACTION" "Focusing space $target_space"
    $y -m space --focus "$target_space"
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "DEBUG" "Focus space command executed"
    focus_window "$window_id"
    
    log_state "AFTER_STATE"
    ;;

  *)
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "ERROR" "Invalid action '$ACTION' specified"
    echo "Error: Invalid action '$ACTION'. Use one of: space-left, space-right, window-left, window-right" >&2
    "$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution failed - invalid action"
    exit 1
    ;;
esac

"$LOGGER_SCRIPT_PATH" "$SCRIPT_NAME" "END" "Script execution finished" 