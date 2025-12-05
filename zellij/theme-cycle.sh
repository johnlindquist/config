#!/usr/bin/env bash
set -euo pipefail

config="${ZELLIJ_CONFIG_FILE:-$HOME/.config/zellij/config.kdl}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zellij"
cache_file="$cache_dir/theme-cycle.idx"
mkdir -p "$cache_dir"

# Collect available themes: start with built-in default, then any defined in config.kdl.
themes=("default")
if [[ -f "$config" ]]; then
  while IFS= read -r name; do
    # de-dup
    skip=false
    for existing in "${themes[@]}"; do
      if [[ "$existing" == "$name" ]]; then
        skip=true
        break
      fi
    done
    [[ "$skip" == true ]] || themes+=("$name")
  done < <(awk '
    /^themes[[:space:]]*{/ { in_block=1; next }
    in_block && /^}/ { in_block=0; next }
    in_block && /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*{/ {
      gsub(/[[:space:]]*{/, "", $1); print $1
    }
  ' "$config")
fi

total=${#themes[@]}
if (( total == 0 )); then
  echo "No themes found; falling back to default." >&2
  themes=("default")
  total=1
fi

direction="${1:-next}"
step=1
case "$direction" in
  prev|up) step=-1 ;;
  next|down) step=1 ;;
  *) step=1 ;;
esac

# Determine starting index: cache > config theme > 0.
if [[ -f "$cache_file" ]] && read -r cached <"$cache_file" 2>/dev/null; then
  current_index=$cached
else
  current_index=0
  if [[ -f "$config" ]]; then
    if current_theme_line=$(grep -m1 '^theme[[:space:]]*"' "$config"); then
      current_theme=$(printf '%s\n' "$current_theme_line" | sed -E 's/^theme[[:space:]]*"([^"]+)".*/\1/')
      for i in "${!themes[@]}"; do
        if [[ "${themes[$i]}" == "$current_theme" ]]; then
          current_index=$i
          break
        fi
      done
    fi
  fi
fi

next_index=$(( (current_index + step + total) % total ))
next_theme="${themes[$next_index]}"

if zellij options --theme "$next_theme" >/dev/null 2>&1; then
  echo "$next_index" > "$cache_file"
  printf 'Theme: %s\n' "$next_theme"
else
  printf 'Failed to set theme: %s\n' "$next_theme" >&2
  exit 1
fi
