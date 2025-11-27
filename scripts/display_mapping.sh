#!/usr/bin/env bash

# Helper to map a logical 2x2 grid slot to an actual yabai display index.
# Grid slots:
#   1 = top-left
#   2 = top-right
#   3 = bottom-left
#   4 = bottom-right
# Uses $YABAI_PATH and $JQ_PATH if set by the caller; otherwise defaults.

get_display_index_for_grid_slot() {
  local slot="$1"
  local zero_based_idx=$((slot - 1))
  local y="${YABAI_PATH:-/opt/homebrew/bin/yabai}"
  local jq="${JQ_PATH:-/opt/homebrew/bin/jq}"

  "$y" -m query --displays | \
    "$jq" -r --argjson idx "$zero_based_idx" '
      # Build a simple list of displays with coordinates
      [ .[] | { index: .index, x: .frame.x, y: .frame.y } ] as $d
      | ($d | length) as $n
      | if $n == 0 then empty else
          # Sort by vertical position and split into two rows (top half, bottom half)
          ($d | sort_by(.y)) as $byy
          | ($n / 2 | floor) as $half
          | ($byy[:$half] | sort_by(.x)) as $top
          | ($byy[$half:] | sort_by(.x)) as $bottom
          | ($top + $bottom) as $grid
          | ($grid[$idx].index // empty)
        end
    '
}
