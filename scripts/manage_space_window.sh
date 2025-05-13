#!/usr/bin/env bash
# ---------- manage_space_window.sh ----------
# Manages spaces and windows based on the first argument.
# Arguments:
#   space-left:   Focus/create space to the left.
#   space-right:  Focus/create space to the right.
#   window-left:  Move focused window left (create space if needed).
#   window-right: Move focused window right (create space if needed).

# --- Config ---
DEBUG=false # Set to true to enable logging

# --- Logging Setup ---
LOG_FILE="$HOME/.config/logs/manage_space_window.log"

log() {
  if [[ "$DEBUG" == "true" ]]; then
    # Ensure log dir exists only when debugging
    mkdir -p "$(dirname "$LOG_FILE")"
    # Append timestamp and message
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $@" >> "$LOG_FILE"
  fi
}

# --- Argument Handling ---
ACTION="$1"

if [[ "$DEBUG" == "true" ]]; then
  # Redirect stderr to log file only when debugging
  exec 2>> "$LOG_FILE"
  log "--- Script Start ---"
  log "Requested Action: $ACTION"
fi

if [[ -z "$ACTION" ]]; then
  log "Error: No action specified."
  echo "Error: No action specified. Use one of: space-left, space-right, window-left, window-right" >&2
  exit 1
fi

# --- Script Logic ---
y=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

# --- Helper Functions ---
get_focused_window_id() {
  local id
  log "Getting focused window ID..."
  id=$($y -m query --windows --window | $jq '.id')
  if [[ -z "$id" || "$id" == "null" ]]; then
      log "Error: Could not get focused window ID."
      # Optionally exit or return an error code/empty string
      echo "" # Return empty string on failure
  else
      log "Focused window ID: $id"
      echo "$id"
  fi
}

focus_window() {
  local window_id="$1"
  if [[ -n "$window_id" ]]; then
    log "Refocusing window $window_id..."
    $y -m window --focus "$window_id"
    log "Refocus window command executed."
  fi
}

# --- Main Logic based on Action ---

case "$ACTION" in
  space-left)
    log "Action: space-left"
    log "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    log "Current space index: $cur"
    log "Querying previous space index..."
    prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index < $cur)) | sort_by(.index) | .[-1].index // "" ')
    log "Previous space index: '$prev'"

    if [[ "$prev" == '""' ]]; then
      log "Edge detected (prev is \"\"), creating new space..."
      $y -m space --create
      log "Create command executed."
      log "Querying last space index (new one)..."
      new=$($y -m query --spaces --display | $jq '.[-1].index')
      log "New space index: $new"
      log "Focusing new space ($new) temporarily..."
      $y -m space --focus "$new"
      log "Temporary focus command executed."
      log "Moving new space ($new) to position 1..."
      $y -m space --move 1
      log "Move command executed."
      log "Focusing space 1..."
      $y -m space --focus 1
      log "Focus command executed."
    else
      log "Neighbour found ('$prev'), focusing..."
      $y -m space --focus "$prev"
      log "Focus command executed."
    fi
    ;;

  space-right)
    log "Action: space-right"
    log "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    log "Current space index: $cur"
    log "Querying next space index..."
    next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index > $cur)) | sort_by(.index) | .[0].index // "" ')
    log "Next space index: '$next'"

    if [[ "$next" == '""' ]]; then
      log "Edge detected (next is \"\"), creating new space..."
      $y -m space --create
      log "Create command executed."
      log "Querying last space index..."
      last=$($y -m query --spaces --display | $jq '.[-1].index')
      log "Last space index: $last"
      log "Focusing space $last..."
      $y -m space --focus "$last"
      log "Focus command executed."
    else
      log "Neighbour found ('$next'), focusing..."
      $y -m space --focus "$next"
      log "Focus command executed."
    fi
    ;;

  window-left)
    log "Action: window-left"
    window_id=$(get_focused_window_id)
    if [[ -z "$window_id" ]]; then exit 1; fi

    log "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    log "Current space index: $cur"
    log "Querying previous space index..."
    prev=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index < $cur)) | sort_by(.index) | .[-1].index // "" ')
    log "Previous space index: '$prev'"

    target_space=""
    if [[ "$prev" == '""' ]]; then
      log "Edge detected (prev is \"\"), creating new space..."
      $y -m space --create
      log "Create command executed."
      log "Querying last space index (new one)..."
      new=$($y -m query --spaces --display | $jq '.[-1].index')
      log "New space index: $new"
      log "Focusing new space ($new) temporarily..."
      $y -m space --focus "$new"
      log "Temporary focus command executed."
      log "Moving new space ($new) to position 1..."
      $y -m space --move 1
      log "Move command executed."
      target_space=1
      log "Target space set to: $target_space"
    else
      target_space="$prev"
      log "Target space set to: $target_space"
    fi

    log "Moving window $window_id to space $target_space..."
    $y -m window "$window_id" --space "$target_space"
    log "Move command executed."
    log "Focusing space $target_space..."
    $y -m space --focus "$target_space"
    log "Focus space command executed."
    focus_window "$window_id"
    ;;

  window-right)
    log "Action: window-right"
    window_id=$(get_focused_window_id)
    if [[ -z "$window_id" ]]; then exit 1; fi

    log "Querying current space index..."
    cur=$($y -m query --spaces --space | $jq '.index')
    log "Current space index: $cur"
    log "Querying next space index..."
    next=$($y -m query --spaces --display | $jq --argjson cur "$cur" '
            map(select(.index > $cur)) | sort_by(.index) | .[0].index // "" ')
    log "Next space index: '$next'"

    target_space=""
    if [[ "$next" == '""' ]]; then
      log "Edge detected (next is \"\"), creating new space..."
      $y -m space --create
      log "Create command executed."
      log "Querying last space index..."
      last=$($y -m query --spaces --display | $jq '.[-1].index')
      log "Last space index: $last"
      target_space="$last"
      log "Target space set to: $target_space"
    else
      target_space="$next"
      log "Target space set to: $target_space"
    fi

    log "Moving window $window_id to space $target_space..."
    $y -m window "$window_id" --space "$target_space"
    log "Move command executed."
    log "Focusing space $target_space..."
    $y -m space --focus "$target_space"
    log "Focus space command executed."
    focus_window "$window_id"
    ;;

  *)
    log "Error: Invalid action '$ACTION' specified."
    echo "Error: Invalid action '$ACTION'. Use one of: space-left, space-right, window-left, window-right" >&2
    exit 1
    ;;
esac

log "--- Script End ---" 