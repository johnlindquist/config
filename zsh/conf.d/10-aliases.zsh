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
alias s="source \$ZDOTDIR/.zshrc"

#### Package management
alias pup="pnpm dlx npm-check-updates -i -p pnpm"
alias nx='pnpm dlx nx'

#### Process management
alias pke="pkill Electron"

#### Claude shortcuts
alias opus='ENABLE_BACKGROUND_TASKS=1 claude --model opus'

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
