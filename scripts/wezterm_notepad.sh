#!/bin/bash
# wezterm_notepad.sh - Open notes in micro, auto-commit on exit

NOTES_DIR="$HOME/dev/notes"
NOTES_FILE="$NOTES_DIR/notes.md"

# Ensure directory exists
mkdir -p "$NOTES_DIR"

# Initialize git if needed
if [[ ! -d "$NOTES_DIR/.git" ]]; then
  git -C "$NOTES_DIR" init
fi

# Create file if it doesn't exist
[[ -f "$NOTES_FILE" ]] || echo "# Notes" > "$NOTES_FILE"

# Open in micro
cd "$NOTES_DIR"
micro "$NOTES_FILE"

# Auto-commit on exit (if there are changes)
if [[ -n $(git -C "$NOTES_DIR" status --porcelain) ]]; then
  git -C "$NOTES_DIR" add -A
  git -C "$NOTES_DIR" commit -m "notes: $(date '+%Y-%m-%d %H:%M')"
fi
