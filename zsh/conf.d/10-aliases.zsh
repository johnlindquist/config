# =============================================================================
# Aliases & Small Helpers
# =============================================================================
# Universal aliases and functions. Machine-specific ones go in local.zsh
# =============================================================================

#### Better defaults (requires: brew install bat eza trash)
command -v bat &>/dev/null && alias cat='bat --no-pager'
command -v eza &>/dev/null && alias ls='eza'
command -v trash &>/dev/null && alias rm='trash'

#### Editor shortcuts (override EDITOR_CMD in local.zsh)
: "${EDITOR_CMD:=cursor}"
alias zd="zed"
alias s='source $ZDOTDIR/.zshrc'

#### Package management
alias pup="pnpm dlx npm-check-updates -i -p pnpm"
alias nx='pnpm dlx nx'

#### Process management
alias pke="pkill Electron"

#### Claude shortcuts
alias opus='ENABLE_BACKGROUND_TASKS=1 claude --model opus'

# Semantic search across Claude session history
# Uses semtools' search for embedding-based matching
# Usage: csearch "query" [--top-k N] [--days N] [--all]
csearch() {
  [[ -z "$1" ]] && { echo "Usage: csearch <query> [--top-k N] [--days N] [--all]"; return 1; }
  command -v search &>/dev/null || { echo "semtools not installed: npm i -g @llamaindex/semtools"; return 1; }

  local query="$1"
  shift
  local projects_dir="$HOME/.claude/projects"
  local days=7  # Default to last 7 days
  local search_args=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days) days="$2"; shift 2 ;;
      --all) days=9999; shift ;;
      *) search_args+=("$1"); shift ;;
    esac
  done

  # Extract user messages with session context, pipe to semantic search
  /bin/bash -c '
    find "'"$projects_dir"'" -name "*.jsonl" -type f -mtime -'"$days"' | while read -r f; do
      session=$(basename "$f" .jsonl)
      proj=$(basename "$(dirname "$f")" | sed "s/-Users-[^-]*-/~/")
      cat "$f" | jq -r "select(.type==\"user\") | .message.content | if type==\"string\" then . else empty end" 2>/dev/null | \
        while IFS= read -r line; do
          [[ -n "$line" ]] && echo "[$session @ $proj] $line"
        done
    done
  ' | search "$query" "${search_args[@]}" --n-lines 0
}

# List recent Claude sessions with their first message
csessions() {
  local projects_dir="$HOME/.claude/projects"
  local limit="${1:-10}"

  /bin/bash -c '
    find "'"$projects_dir"'" -name "*.jsonl" ! -name "agent-*" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | \
      sort -rn | head -'"$limit"' | while read -r ts file; do
        session=$(basename "$file" .jsonl)
        proj=$(basename "$(dirname "$file")" | sed "s/-Users-[^-]*-/~/g")
        first_msg=$(cat "$file" | jq -r "select(.type==\"user\") | .message.content | if type==\"string\" then .[0:80] else empty end" 2>/dev/null | head -1)
        [[ -n "$first_msg" ]] && printf "%-36s  %s\n   %s\n\n" "$session" "${proj:0:35}" "$first_msg"
      done
  '
}

# Resume a Claude session by searching for it
# Usage: cresume "what was I working on" or cresume (interactive)
cresume() {
  command -v fzf &>/dev/null || { echo "fzf required"; return 1; }

  local projects_dir="$HOME/.claude/projects"
  local session

  if [[ -n "$1" ]]; then
    # Search for session by content using semantic search
    session=$(csearch "$1" --top-k 5 2>/dev/null | \
      grep -oE '\[[a-f0-9-]{36}' | tr -d '[' | head -1)
  fi

  if [[ -z "$session" ]]; then
    # Interactive selection with fzf
    session=$(/bin/bash -c '
      find "'"$projects_dir"'" -name "*.jsonl" ! -name "agent-*" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | \
        sort -rn | head -50 | while read -r ts file; do
          sid=$(basename "$file" .jsonl)
          proj=$(basename "$(dirname "$file")" | sed "s/-Users-[^-]*-/~/g" | cut -c1-30)
          msg=$(cat "$file" | jq -r "select(.type==\"user\") | .message.content | if type==\"string\" then .[0:60] else empty end" 2>/dev/null | head -1)
          [[ -n "$msg" ]] && echo "$sid|$proj|$msg"
        done
    ' | fzf --delimiter='|' --with-nth=2,3 --preview='echo Session: {1}' | cut -d'|' -f1)
  fi

  [[ -z "$session" ]] && { echo "No session selected"; return 1; }
  claude -r "$session"
}

# Launch claude with a predefined agent
# Usage: cagent <agent-name> [prompt]
# Agents: reviewer, debugger, refactor, docs, security
cagent() {
  local -A agents=(
    [reviewer]='{"description":"Expert code reviewer","prompt":"You are a senior code reviewer. Focus on code quality, security, best practices, and maintainability. Run git diff to see changes, then provide actionable feedback organized by priority.","tools":["Read","Grep","Glob","Bash"]}'
    [debugger]='{"description":"Debugging specialist","prompt":"You are an expert debugger. Analyze errors, trace root causes, and provide minimal fixes. Focus on understanding the problem before suggesting solutions.","tools":["Read","Edit","Bash","Grep","Glob"]}'
    [refactor]='{"description":"Refactoring expert","prompt":"You are a refactoring specialist. Improve code structure without changing behavior. Focus on readability, maintainability, and removing duplication.","tools":["Read","Edit","Grep","Glob"]}'
    [docs]='{"description":"Documentation writer","prompt":"You are a technical writer. Create clear, concise documentation. Focus on examples and practical usage.","tools":["Read","Write","Glob"]}'
    [security]='{"description":"Security auditor","prompt":"You are a security expert. Audit code for vulnerabilities including OWASP top 10, secrets exposure, and injection attacks. Provide severity ratings and fixes.","tools":["Read","Grep","Glob","Bash"]}'
  )

  [[ -z "$1" ]] && {
    echo "Usage: cagent <agent> [prompt]"
    echo "Agents: ${(k)agents}"
    return 1
  }

  local agent="$1"
  shift

  [[ -z "${agents[$agent]}" ]] && {
    echo "Unknown agent: $agent"
    echo "Available: ${(k)agents}"
    return 1
  }

  local json="{\"$agent\":${agents[$agent]}}"
  claude --agents "$json" "$@"
}

# =============================================================================
# Functions
# =============================================================================

# Cursor/editor helper - opens or creates file/dir
unalias c 2>/dev/null
c() {
  local cmd="${EDITOR_CMD:-cursor}"
  if [[ $# -eq 0 ]]; then
    "$cmd" .
  else
    if [[ ! -e "$1" ]]; then
      if [[ "$1" == .* || "$1" == *.* ]]; then
        touch "$1"
      else
        mkdir -p "$1"
      fi
    fi
    "$cmd" "$@"
  fi
}

# Clone repo and setup
clone() {
  local repo="$1"
  local dir="${2:-${repo##*/}}"
  gh repo clone "https://github.com/$repo" "$dir"
  cd "$dir" || return
  command -v pnpm &>/dev/null && pnpm i
}

# Env file runner
with_env() {
  [[ -f .env ]] || { echo "No .env in $(pwd)"; return 1; }
  ( export $(grep -v '^#' .env | xargs) && "$@" )
}

# Cat multiple files with headers
files() {
  for file in "$@"; do
    [[ -d "$file" ]] && continue
    echo "=== $file ==="
    cat "$file"
    echo
  done
}

# Slugify text for filenames
slugify() {
  tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | tr ' ' '-' | tr '/' '-'
}

# MCP inspector
mcpi() { bunx @modelcontextprotocol/inspector@latest "$@"; }

# Edit a shell function in cursor at its definition
funced() {
  [[ -z "$1" ]] && { echo "Usage: funced <function_name>"; return 1; }
  local func="$1"

  # Check if it's a function
  [[ $(whence -w "$func" 2>/dev/null) != *function* ]] && {
    echo "'$func' is not a function"
    return 1
  }

  # Get source file from functions_source (zsh 5.3+)
  local file="${functions_source[$func]}"
  [[ -z "$file" || ! -f "$file" ]] && {
    echo "Can't find source file for '$func'"
    return 1
  }

  # Find line number (matches "funcname() {" or "function funcname")
  local line=$(grep -n -m1 "^\s*\(function \)\?${func}\s*(" "$file" | cut -d: -f1)
  [[ -z "$line" ]] && line=1

  cursor -g "$file:$line"
}

# =============================================================================
# Project Scaffolding
# =============================================================================

# Next.js app with standard config
next_app() {
  local target_dir="${1:-.}"
  yes '' | pnpm create next-app@latest "$target_dir" \
    --tailwind --biome --typescript --app --no-src-dir --import-alias "@/*" --overwrite \
  && echo "✅ Next.js app created in '$target_dir'" || { echo "❌ Failed"; return 1; }
}

# Bun project init
binit() { bun init --yes; }

# Node project init with TypeScript
pinit() {
  local node_ver="${NODE_VERSION:-23.6.1}"
  pnpm init
  pnpm pkg set type=module
  pnpm pkg set scripts.dev="node --env-file=.env --no-warnings index.ts"
  pnpm set --location project use-node-version "$node_ver"
  pnpm add -D @types/node "@tsconfig/node${node_ver%%.*}" @tsconfig/strictest
  pnpm dlx gitignore Node
  cat > tsconfig.json <<JSON
{
  "\$schema": "https://json.schemastore.org/tsconfig",
  "extends": ["@tsconfig/node${node_ver%%.*}/tsconfig.json", "@tsconfig/strictest/tsconfig.json"]
}
JSON
  cat > index.ts <<'TS'
console.log("Hello, TypeScript!");
TS
  git init && git add . && git commit -m "feat: project setup"
}

# Share React project with CodeSandbox badge
share-react-project() {
  [[ -z "$1" ]] && { echo "Usage: share-react-project <project_name>"; return 1; }
  local project_name="$1"
  local github_username
  github_username=$(gh api /user --jq '.login')

  pnpm create vite "$project_name" --template react
  cd "$project_name" || return
  git init && git add . && git commit -m "Initial commit"

  local codesandbox_link="https://codesandbox.io/p/github/${github_username}/${project_name}"
  echo -e "\n## CodeSandbox\n[![Open in CodeSandbox](https://assets.codesandbox.io/github/button-edit-blue.svg)](${codesandbox_link})" >> README.md

  git add README.md && git commit -m "Add CodeSandbox link"
  gh repo create "$github_username/$project_name" --public
  git push -u origin main

  echo "✅ Created: https://github.com/$github_username/$project_name"
}

# =============================================================================
# Tmux Helpers
# =============================================================================

# Launch multiple AI CLIs in tmux panes
muxai() {
  local session="${1:-ai}"
  local window="${2:-bots}"
  local -a cmds=(claude gemini copilot codex)

  command -v tmux &>/dev/null || { echo "tmux not found"; return 1; }

  local win_id pane_id win_info

  if [[ -n "$TMUX" ]]; then
    win_info=$(tmux new-window -P -F "#{window_id}|#{pane_id}" -n "$window")
    win_id="${win_info%%|*}"
    pane_id="${win_info##*|}"
  else
    if tmux has-session -t "$session" 2>/dev/null; then
      win_info=$(tmux new-window -t "$session" -P -F "#{window_id}|#{pane_id}" -n "$window")
      win_id="${win_info%%|*}"
      pane_id="${win_info##*|}"
    else
      tmux new-session -d -s "$session" -n "$window"
      win_id=$(tmux display-message -p -t "$session:$window" "#{window_id}")
      pane_id=$(tmux list-panes -t "$session:$window" -F "#{pane_id}" | head -n1)
    fi
  fi

  tmux set-window-option -t "$win_id" remain-on-exit on >/dev/null
  tmux send-keys -t "$pane_id" "${cmds[1]}" C-m

  local current="$pane_id" new_pane i
  for (( i=2; i<=${#cmds[@]}; i++ )); do
    if (( i % 2 == 0 )); then
      new_pane=$(tmux split-window -P -F "#{pane_id}" -t "$current" -h)
    else
      new_pane=$(tmux split-window -P -F "#{pane_id}" -t "$current" -v)
    fi
    tmux send-keys -t "$new_pane" "${cmds[i]}" C-m
    current="$new_pane"
  done

  tmux select-layout -t "$win_id" tiled >/dev/null
  [[ -z "$TMUX" ]] && tmux attach -t "$session"
}

# =============================================================================
# Video Chunking for Upload
# =============================================================================
# Splits large video files into upload-friendly chunks (default 200MB)
# Usage: vid-chunk input.mp4 [target_mb]

vid-chunk() {
  local input="$1"
  local target_mb="${2:-200}"

  [[ -z "$input" || ! -f "$input" ]] && { echo "Usage: vid-chunk <video.mp4> [target_mb]"; return 1; }
  command -v ffmpeg &>/dev/null || { echo "ffmpeg required"; return 1; }
  command -v ffprobe &>/dev/null || { echo "ffprobe required"; return 1; }

  local basename="${input%.*}"
  local ext="${input##*.}"
  local output_dir="${basename}_chunks"
  mkdir -p "$output_dir"

  # Get video info
  local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null)
  local file_size=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input" 2>/dev/null)
  local bitrate=$(echo "scale=0; $file_size * 8 / $duration" | bc)

  # Calculate chunk duration based on target size
  local target_bytes=$((target_mb * 1024 * 1024))
  local chunk_duration=$(echo "scale=2; $target_bytes * 8 * 0.95 / $bitrate" | bc)

  echo "📹 Input: $input"
  echo "   Duration: ${duration}s | Size: $(echo "scale=1; $file_size / 1024 / 1024" | bc)MB"
  echo "   Target chunk: ${target_mb}MB (~${chunk_duration}s each)"
  echo "   Output: $output_dir/"
  echo ""

  local chunk_num=1
  local current_time=0

  while (( $(echo "$current_time < $duration - 0.5" | bc -l) )); do
    local output_file="$output_dir/chunk_$(printf "%03d" $chunk_num).$ext"
    local remaining=$(echo "$duration - $current_time" | bc)
    local segment_duration=$(echo "if ($remaining < $chunk_duration) $remaining else $chunk_duration" | bc)

    echo -n "Creating chunk $chunk_num... "
    ffmpeg -ss "$current_time" -i "$input" -t "$segment_duration" \
      -fs "${target_mb}M" -c copy -avoid_negative_ts make_zero \
      "$output_file" -y 2>/dev/null

    if [[ -f "$output_file" ]]; then
      local chunk_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
      local chunk_mb=$(echo "scale=1; $chunk_size / 1024 / 1024" | bc)
      local actual_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_file" 2>/dev/null)
      current_time=$(echo "$current_time + $actual_duration" | bc)
      echo "✓ ${chunk_mb}MB (${actual_duration}s)"
      ((chunk_num++))
    else
      echo "✗ Failed"
      break
    fi
  done

  echo ""
  echo "✅ Created $((chunk_num - 1)) chunks in $output_dir/"
  ls -lh "$output_dir"
}

# =============================================================================
# Smart Project Navigator
# =============================================================================
# Type "dev " (with space) to instantly trigger fuzzy project search
# The space key triggers fzf when "dev" is on the command line
#
# Environment variables:
#   DEV_DIR     - Directory to search for projects (default: ~/dev)
#   DEV_EDITOR  - Editor to open selected project (default: result of `which cursor`)
#                 Set to empty string "" to disable auto-opening editor
#
# Examples:
#   export DEV_EDITOR="code"      # Use VS Code
#   export DEV_EDITOR="zed"       # Use Zed
#   export DEV_EDITOR=""          # Just cd, don't open editor
#   export DEV_DIR="$HOME/projects"  # Use different directory

: "${DEV_DIR:=$HOME/dev}"
: "${DEV_EDITOR:=$(command -v cursor 2>/dev/null)}"
: "${DEV_CACHE:=$HOME/.cache/dev_projects}"

# Refresh dev project cache (runs in background after use)
_dev_refresh_cache() {
  find "$DEV_DIR" -maxdepth 1 -type d ! -name ".*" -exec stat -f "%m %N" {} \; 2>/dev/null | \
    sort -rn | cut -d' ' -f2- | sed "s|$DEV_DIR/||" | grep -v "^$DEV_DIR$" > "$DEV_CACHE"
}

# Get cached project list (refresh if missing or stale >5min)
_dev_get_projects() {
  local cache_age=300  # 5 minutes
  if [[ ! -f "$DEV_CACHE" ]] || [[ $(( $(date +%s) - $(stat -f %m "$DEV_CACHE") )) -gt $cache_age ]]; then
    _dev_refresh_cache
  fi
  cat "$DEV_CACHE"
  # Refresh in background for next time
  (_dev_refresh_cache &) 2>/dev/null
}

# Base function: fzf select project and cd (no editor)
_dev_cd() {
  local target=$(_dev_get_projects | \
    fzf --height 40% --reverse --preview "ls -la $DEV_DIR/{} 2>/dev/null | head -10")

  [[ -z "$target" ]] && return 1

  local full_path="$DEV_DIR/$target"
  cd "$full_path" || return 1

  # Show project info
  if [[ -f package.json ]]; then
    local name=$(jq -r '.name // empty' package.json 2>/dev/null)
    local desc=$(jq -r '.description // empty' package.json 2>/dev/null)
    [[ -n "$name" ]] && echo "📦 $name"
    [[ -n "$desc" ]] && echo "   $desc"
  elif [[ -f Cargo.toml ]]; then
    echo "🦀 $(grep -m1 '^name' Cargo.toml | cut -d'"' -f2)"
  elif [[ -f go.mod ]]; then
    echo "🐹 $(head -1 go.mod | awk '{print $2}')"
  elif [[ -f pyproject.toml ]]; then
    echo "🐍 $(grep -m1 '^name' pyproject.toml | cut -d'"' -f2)"
  fi

  # Show git status if it's a repo
  if [[ -d .git ]]; then
    local branch=$(git branch --show-current 2>/dev/null)
    local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "🌿 $branch ($changes uncommitted)"
  fi
}

# Navigate to project and open in editor
_dev_navigate() {
  _dev_cd || return 0

  # Open in editor if DEV_EDITOR is set
  if [[ -n "$DEV_EDITOR" ]]; then
    local app_name="${DEV_EDITOR:t}"
    if [[ "$app_name" == "cursor" ]]; then
      cursor -r "$(pwd)" &>/dev/null &
      sleep 0.1
      osascript -e 'tell application "System Events" to set frontmost of process "Cursor" to true'
    else
      "$DEV_EDITOR" "$(pwd)"
    fi
  fi
}

# devx: Navigate to project then run x (for use with wezterm hotkey)
devx() {
  _dev_cd && x
}

# =============================================================================
# ZLE Space Triggers
# =============================================================================
# Trigger commands instantly when typing "<command> " (command + space)
# Add new triggers to the _SPACE_TRIGGERS associative array
#
# Format: _SPACE_TRIGGERS[command]="function_to_call"

typeset -gA _SPACE_TRIGGERS
_SPACE_TRIGGERS[dev]="_dev_navigate"
_SPACE_TRIGGERS[z]="__zoxide_zi"

# Universal space trigger - checks all registered commands
_space_trigger() {
  if [[ -n "${_SPACE_TRIGGERS[$BUFFER]}" ]]; then
    local func="${_SPACE_TRIGGERS[$BUFFER]}"
    BUFFER=""
    zle redisplay
    eval "$func"
    zle reset-prompt
  else
    zle self-insert
  fi
}

zle -N _space_trigger
bindkey " " _space_trigger
