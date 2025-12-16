#!/bin/bash
# wezterm_copy_path.sh - Browse directories with fzf, copy selected path
# Navigation: ←/→ or Ctrl+H/L to go up/into directories, Enter to copy

DIR="${1:-$HOME}"

while true; do
  # Get entries, sorted (directories first, then files)
  ENTRIES=$(cd "$DIR" && {
    # Parent directory option (if not root)
    [[ "$DIR" != "/" ]] && echo ".. (go up)"
    # Directories first (with / suffix for visibility)
    find . -maxdepth 1 -type d ! -name '.' | sed 's|^\./||' | sort | while read d; do echo "$d/"; done
    # Then files
    find . -maxdepth 1 -type f | sed 's|^\./||' | sort
  })

  # Show current path and let user select
  DISPLAY_DIR="${DIR/#$HOME/~}"
  SELECTION=$(echo "$ENTRIES" | fzf \
    --header="📁 $DISPLAY_DIR | ←/Ctrl+H: up | →/Ctrl+L: into | Enter: copy" \
    --preview="[[ -d '$DIR/{}' ]] && ls -la '$DIR/{}' 2>/dev/null | head -20 || head -50 '$DIR/{}' 2>/dev/null" \
    --preview-window=right:50%:wrap \
    --bind='left:abort+execute(echo "GO_UP")' \
    --bind='ctrl-h:abort+execute(echo "GO_UP")' \
    --bind='right:accept' \
    --bind='ctrl-l:accept' \
    --height=80% \
    --reverse \
    --no-mouse)

  # Handle exit/cancel
  [[ -z "$SELECTION" ]] && exit 0

  # Handle "go up"
  if [[ "$SELECTION" == ".. (go up)" || "$SELECTION" == "GO_UP" ]]; then
    DIR=$(dirname "$DIR")
    continue
  fi

  # Remove trailing slash for processing
  SELECTION="${SELECTION%/}"
  FULL_PATH="$DIR/$SELECTION"

  # If directory, navigate into it
  if [[ -d "$FULL_PATH" ]]; then
    DIR="$FULL_PATH"
    continue
  fi

  # If file (or explicit selection), copy path to clipboard
  if [[ -e "$FULL_PATH" ]]; then
    echo -n "$FULL_PATH" | pbcopy
    echo "Copied: $FULL_PATH"
    exit 0
  fi
done
