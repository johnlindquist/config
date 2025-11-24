# =========================
# Git Helpers & Worktree Management
# =========================

#### Conventional commit helpers
unalias fix feat chore push 2>/dev/null
cfix()  { local scope="$1" message="$2"; git add . && git commit -m "fix($scope): $message"; }
fix()   { local scope="$1" message="$2"; git add . && git commit -m "fix($scope): $message" && git push; }
feat()  { local scope="$1" message="$2"; git add . && git commit -m "feat($scope): $message" && git push; }
chore() { local scope="$1" message="$2"; git add . && git commit -m "chore($scope): $message" && git push; }
push()  { git add . && git commit -m "fix: tweak" && git push; }

#### GitHub code search (with logs + snippets)
ghsearch() {
  local ORIGINAL_PATH="$PATH"
  local debug=1
  local timestamp=$(/bin/date +%Y%m%d-%H%M%S)
  local log_dir="$HOME/searches/logs"
  local log_file="$log_dir/ghsearch-$timestamp.log"
  /bin/mkdir -p "$log_dir" 2>/dev/null

  log() { local level="$1" msg="$2"; [[ "$level" == DEBUG && $debug -eq 0 ]] && return; echo "[$level] $msg" | /usr/bin/tee -a "$log_file"; }

  log DEBUG "Starting ghsearch"
  log DEBUG "Command: ghsearch $*"

  export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$ORIGINAL_PATH"
  log DEBUG "PATH: $PATH"

  local query="$*"
  [[ -z "$query" ]] && { log ERROR "No query provided"; return 1; }
  [[ "$query" =~ [^a-zA-Z0-9[:space:]/_.-] ]] && log WARN "Query contains special chars: $query"

  local sanitized_query
  sanitized_query=$(/bin/echo "$query" | /usr/bin/tr -c '[:alnum:]_-' '_' | /usr/bin/sed 's/_*$//')
  local results_dir="$HOME/searches"
  local results_file="$results_dir/$sanitized_query-$timestamp.md"
  /bin/mkdir -p "$results_dir" 2>/dev/null
  log INFO "Saving to: $results_file"

  local gh_path=$(/usr/bin/which gh 2>/dev/null)
  local jq_path=$(/usr/bin/which jq 2>/dev/null)
  local curl_path=$(/usr/bin/which curl 2>/dev/null)
  [[ -z $gh_path || -z $jq_path || -z $curl_path ]] && { log ERROR "Install gh, jq, curl"; return 1; }

  log INFO "Executing GitHub search"
  local search_output
  search_output=$(/opt/homebrew/bin/gh search code "$query" --json path,repository,url --limit 30)
  local gh_exit="$?"
  [[ "$gh_exit" -ne 0 ]] && { log ERROR "gh failed ($gh_exit)"; log ERROR "Raw: $search_output"; return 1; }

  if ! /bin/echo "$search_output" | /opt/homebrew/bin/jq . >/dev/null 2>&1; then
    log ERROR "Invalid JSON"; log ERROR "Raw: $search_output"; return 1
  fi

  local count
  count=$(/bin/echo "$search_output" | /opt/homebrew/bin/jq 'length')
  log DEBUG "Found $count results"

  {
    /bin/echo "# GitHub Code Search Results"
    /bin/echo "Query: \`$query\`"
    /bin/echo "Date: $(/bin/date)"
    /bin/echo
    if [ "$count" -eq 0 ]; then
      /bin/echo "No results found."
    else
      /bin/echo "Found $count results. Showing snippets."
      /bin/echo
      /bin/echo "## Results"
      /bin/echo
      /bin/echo "$search_output" \
      | /opt/homebrew/bin/jq -r \
        '.[] | "### [\(.repository.nameWithOwner)](\(.repository.url))\n\nFile: [\(.path)](\(.url))\n\n```" + (.path | match("\\.[a-zA-Z0-9]+$") | .string[1:] // "") + "\n# Content from \(.path):\n" + (.url | sub("github.com"; "raw.githubusercontent.com") | sub("/blob/"; "/")) + "\n"' \
      | while read -r line; do
          if [[ "$line" =~ ^https ]]; then
            content=$(/usr/bin/curl -s -L "$line")
            if [ -n "$content" ]; then
              /bin/echo "$content" | /usr/bin/awk '{printf "%4d: %s\n", NR, $0}' | /usr/bin/head -n 50
              if [ "$(/bin/echo "$content" | /usr/bin/wc -l)" -gt 50 ]; then
                /bin/echo "... (truncated)"
              fi
            else
              /bin/echo "Failed to fetch $line"
            fi
            /bin/echo '```'
            /bin/echo
            /bin/echo "---"
            /bin/echo
          else
            /bin/echo "$line"
          fi
        done
    fi
  } > "$results_file"

  log DEBUG "Opening results in Cursor"
  if [ -f "$results_file" ]; then
    if ! /Applications/Cursor.app/Contents/MacOS/Cursor "$results_file" 2>/dev/null; then
      log ERROR "Open failed. Use: cursor '$results_file'"
    fi
  fi

  export PATH="$ORIGINAL_PATH"
  log DEBUG "ghsearch complete"
}

#### Git worktree helpers
wtree() {
  local install_deps=false
  local branches=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--pnpm) install_deps=true; shift ;;
      *) branches+=("$1"); shift ;;
    esac
  done
  [[ ${#branches[@]} -eq 0 ]] && { echo "Usage: wtree [-p] branch1 [branch2...]"; return 1; }

  local current_branch repo_root repo_name worktree_parent="$HOME/dev"
  current_branch=$(git rev-parse --abbrev-ref HEAD) || { echo "Not a git repo"; return 1; }
  repo_root=$(git rev-parse --show-toplevel) || { echo "Cannot find repo root"; return 1; }
  repo_name=$(basename "$repo_root")
  mkdir -p "$worktree_parent" || { echo "Cannot create $worktree_parent"; return 1; }

  for branch in "${branches[@]}"; do
    local target="$worktree_parent/${repo_name}-${branch}"
    echo "Processing: $branch → $target"
    if git worktree list | grep -q "^${target}[[:space:]]"; then
      echo "Worktree exists at ${target}. Skipping '${branch}'."
      continue
    fi
    git show-ref --verify --quiet "refs/heads/${branch}" || git branch "${branch}" || { echo "Failed creating '${branch}'"; continue; }
    git worktree add "$target" "${branch}" || { echo "Failed add worktree '${branch}'"; continue; }
    if $install_deps; then
      echo "Installing deps in ${target}..."
      (cd "$target" && pnpm install) || echo "Warning: pnpm install failed"
    fi
    if type cursor >/dev/null 2>&1; then cursor "$target"; else echo "Worktree: ${target}"; fi
    echo "-----------------------------------------------------"
  done
}

wtmerge() {
  [[ $# -eq 1 ]] || { echo "Usage: wtmerge <branch-to-keep>"; return 1; }
  local keep="$1" repo_root repo_name worktree_parent="$HOME/dev"
  repo_root=$(git rev-parse --show-toplevel) || { echo "Not a git repo"; return 1; }
  repo_name=$(basename "$repo_root")

  local worktrees=()
  while IFS= read -r line; do
    local wt_path; wt_path=$(echo "$line" | awk '{print $1}')
    [[ "$wt_path" == "$worktree_parent/${repo_name}-"* ]] && worktrees+=("$wt_path")
  done < <(git worktree list)

  local target=""
  for wt in "${worktrees[@]}"; do
    [[ "$wt" == "$worktree_parent/${repo_name}-${keep}" ]] && target="$wt" && break
  done
  [[ -z "$target" ]] && { echo "No worktree for '${keep}' under ${worktree_parent}"; return 1; }

  echo "Checking uncommitted changes in '${keep}'..."
  if ! ( cd "$target" && git diff --quiet && git diff --cached --quiet ); then
    ( cd "$target" && git add . && git commit -m "chore: auto-commit '${keep}' before merge" ) || { echo "Auto-commit failed"; return 1; }
  fi

  echo "Switching to main and merging '${keep}'..."
  git checkout main || { echo "Failed to checkout main"; return 1; }
  git merge "${keep}" -m "feat: merge '${keep}'" || { echo "Merge failed"; return 1; }

  echo "Cleaning worktrees..."
  for wt in "${worktrees[@]}"; do
    local wt_branch; wt_branch=$(basename "$wt"); wt_branch=${wt_branch#${repo_name}-}
    git worktree remove "$wt" --force || echo "Warning: couldn't remove $wt"
    [[ "$wt_branch" != "main" ]] && git branch -D "$wt_branch" || true
  done
  echo "Done."
}

#### Spike (quick experimental branch)
spike() {
  local base; base=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1
  local branch; branch="${1:-spike/${base}-$(date +%s)}"
  echo "🌵 Spiking to $branch ..."
  git switch -c "$branch" || return 1
  git add -A || return 1
  git commit -m "spike(${base}): ${branch##*/}" || return 1
  git switch "$base"
}

#### GitHub helpers
unalias ghv 2>/dev/null
ghv() { gh repo view --web "$@"; }

unalias ghcp 2>/dev/null
ghcp() { GH_PAGER="" gh repo view --json name,owner --jq "\"https://github.com/\" + .owner.login + \"/\" + .name" | pbcopy; }

#### Init new repo
init() {
  if [ ! -f .gitignore ]; then
    echo "Error: No .gitignore file found. Please create a .gitignore file."
    return 1
  fi
  git init
  git add .
  git commit -m "Initial commit"
  gh repo create --private --source=.
  git push -u origin main
  gh repo view --web
}

# =============================================================================
# 👻 Git Ghost Checkpoints
# =============================================================================
# A workflow for saving "invisible" commits (refs/ghosts/) that don't pollute
# your branch history or staging area. Includes auto-cleanup.

GHOST_REF_PREFIX="refs/ghosts"

# 1. SAVE - Snapshots current state to a hidden ref
ghost-save() {
  local msg="${1:-Ghost Checkpoint}"
  local ts=$(date +%s)

  [ -d .git ] || { echo "❌ Not a git repo."; return 1; }

  local temp_index=".git/index.ghost.$ts"
  trap 'rm -f "$temp_index"' EXIT

  cp .git/index "$temp_index" 2>/dev/null
  GIT_INDEX_FILE="$temp_index" git add -A

  local tree=$(GIT_INDEX_FILE="$temp_index" git write-tree)
  local parent=$(git rev-parse HEAD)

  # DEDUPLICATION: Check if this tree matches the last ghost
  local last_ghost=$(git for-each-ref --sort=-committerdate --count=1 --format='%(objectname)' "$GHOST_REF_PREFIX")
  if [[ -n "$last_ghost" ]]; then
    local last_tree=$(git rev-parse "$last_ghost^{tree}")
    if [[ "$last_tree" == "$tree" ]]; then
      _ghost_autoclean
      return 0
    fi
  fi

  local commit=$(echo "$msg" | git commit-tree "$tree" -p "$parent")
  git update-ref "$GHOST_REF_PREFIX/$ts" "$commit"
  echo "👻 Saved ghost: ${commit:0:7}"

  _ghost_autoclean
}

# 2. LOG - Lists the last 20 ghost checkpoints
ghost-log() {
  git for-each-ref --sort=-committerdate "$GHOST_REF_PREFIX/" \
  --format='%(color:yellow)%(refname:short)%(color:reset) | %(color:green)%(objectname:short)%(color:reset) | %(contents:subject) %(color:blue)(%(committerdate:relative))%(color:reset)' \
  | sed "s|$GHOST_REF_PREFIX/||" | head -n 20
}

# 3. RESTORE - Hard resets working directory to a ghost state
ghost-restore() {
  local id="$1"
  local force="$2"

  [ -z "$id" ] && { echo "Usage: ghost-restore <timestamp_id> [--force]"; return 1; }

  if [[ -n $(git status --porcelain) ]] && [[ "$force" != "--force" ]]; then
    echo "⚠️  Working directory is dirty!"
    echo "   Restoring will overwrite your work. Use 'ghost-restore $id --force'."
    return 1
  fi

  local ref="$GHOST_REF_PREFIX/$id"
  if ! git show-ref --quiet "$ref"; then
    echo "❌ Ghost $id not found."
    return 1
  fi

  echo "Rewinding to $id..."
  git read-tree --reset -u "$ref"
}

# 4. EXPORT - Zips a specific ghost state
ghost-export() {
  local id="$1"
  [ -z "$id" ] && { echo "Usage: ghost-export <timestamp_id>"; return 1; }

  local ref="$GHOST_REF_PREFIX/$id"
  if ! git show-ref --quiet "$ref"; then
    echo "❌ Ghost $id not found."
    return 1
  fi

  local filename="ghost-export-${id}.zip"
  git archive --format=zip --output="$filename" "$ref"
  echo "📦 Exported ghost $id to ./$filename"
}

# 5. NUKE - Deletes all ghosts immediately
ghost-nuke() {
  git for-each-ref --format='%(refname)' "$GHOST_REF_PREFIX/" | xargs -L1 git update-ref -d
  echo "💥 All ghosts busted."
}

# INTERNAL: AUTO-CLEANUP - Moves ghosts > 7 days old to /tmp bundles
_ghost_autoclean() {
  local cutoff=$(($(date +%s) - 604800)) # 7 days
  local graveyard="${TMPDIR:-/tmp}/ghost-graveyard"

  git for-each-ref --format='%(refname) %(committerdate:unix)' "$GHOST_REF_PREFIX" \
  | while read ref timestamp; do
    if [[ "$timestamp" -lt "$cutoff" ]]; then
      mkdir -p "$graveyard"
      local short_id=${ref#$GHOST_REF_PREFIX/}
      local bundle_path="$graveyard/ghost-${short_id}.bundle"
      git bundle create "$bundle_path" "$ref" >/dev/null 2>&1
      git update-ref -d "$ref"
    fi
  done
}
