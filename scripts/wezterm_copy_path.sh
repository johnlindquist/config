#!/bin/bash
# wezterm_copy_path.sh - Browse directories with fzf, copy selected path
# Navigation: ←: up | →: into dir | Enter: copy | ⌥.: toggle hidden | Tab/⇧Tab: list

DIR="${1:-$HOME}"
SHOW_HIDDEN=0

get_entries() {
  local dir="$1"
  local show_hidden="$2"

  cd "$dir" || return

  # Parent directory option (if not root)
  [[ "$dir" != "/" ]] && echo ".. (go up)"

  if [[ "$show_hidden" == "1" ]]; then
    # Show all including hidden
    find . -maxdepth 1 -type d ! -name '.' | sed 's|^\./||' | sort | while read -r d; do echo "$d/"; done
    find . -maxdepth 1 -type f | sed 's|^\./||' | sort
  else
    # Hide dotfiles/dotdirs
    find . -maxdepth 1 -type d ! -name '.' ! -name '.*' | sed 's|^\./||' | sort | while read -r d; do echo "$d/"; done
    find . -maxdepth 1 -type f ! -name '.*' | sed 's|^\./||' | sort
  fi
}

while true; do
  DISPLAY_DIR="${DIR/#$HOME/~}"
  HIDDEN_INDICATOR=$([[ "$SHOW_HIDDEN" == "1" ]] && echo "👁 " || echo "")

  ENTRIES=$(get_entries "$DIR" "$SHOW_HIDDEN")

  # Use --expect to capture which key was pressed
  RESULT=$(echo "$ENTRIES" | fzf \
    --header="${HIDDEN_INDICATOR}📁 $DISPLAY_DIR | ←: up | →: into | Enter: copy | ⌥.: hidden" \
    --preview="[[ -d '$DIR/{}' ]] && ls -la '$DIR/{}' 2>/dev/null | head -20 || head -50 '$DIR/{}' 2>/dev/null" \
    --preview-window=right:50%:wrap \
    --expect=left,right,ctrl-h,ctrl-l,alt-. \
    --bind='tab:down' \
    --bind='shift-tab:up' \
    --height=80% \
    --reverse \
    --no-mouse)

  # Parse result: first line is the key pressed, second line is selection
  KEY=$(echo "$RESULT" | head -1)
  SELECTION=$(echo "$RESULT" | tail -1)

  # Handle escape/cancel (both empty)
  [[ -z "$KEY" && -z "$SELECTION" ]] && exit 0

  # Remove trailing slash for path operations
  SELECTION_CLEAN="${SELECTION%/}"
  FULL_PATH="$DIR/$SELECTION_CLEAN"

  # Handle special keys
  case "$KEY" in
    left|ctrl-h)
      # Go up one directory
      [[ "$DIR" != "/" ]] && DIR=$(dirname "$DIR")
      continue
      ;;
    right|ctrl-l)
      # Only enter if it's a directory (ignore for files)
      if [[ "$SELECTION" == ".. (go up)" ]]; then
        [[ "$DIR" != "/" ]] && DIR=$(dirname "$DIR")
      elif [[ -d "$FULL_PATH" ]]; then
        DIR="$FULL_PATH"
      fi
      # If it's a file, do nothing - just loop again
      continue
      ;;
    alt-.)
      # Toggle hidden files
      SHOW_HIDDEN=$((1 - SHOW_HIDDEN))
      continue
      ;;
  esac

  # Enter was pressed (KEY is empty but SELECTION exists)
  if [[ -n "$SELECTION" ]]; then
    # Handle "go up" selection
    if [[ "$SELECTION" == ".. (go up)" ]]; then
      DIR=$(dirname "$DIR")
      continue
    fi

    # Copy the path (works for both files and directories)
    if [[ -e "$FULL_PATH" ]]; then
      echo -n "$FULL_PATH" | pbcopy
      echo "Copied: $FULL_PATH"
      exit 0
    fi
  fi
done
