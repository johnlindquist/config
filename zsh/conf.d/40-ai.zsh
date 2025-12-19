# =========================
# AI/Claude/Gemini Helpers
# =========================

# Claude Code: source shell config for functions/aliases in Bash tool
export CLAUDE_ENV_FILE="$HOME/.claude/shell-init.sh"

#### Google/Web Search
google() {
  [[ $# -eq 0 ]] && { echo "Usage: google \"search query\""; return 1; }
  local search_query="$*"
  local tmpdir; tmpdir=$(mktemp -d)
  local pids=() i=0
  local searches=("$search_query")

  for search in "${searches[@]}"; do
    [[ -z "$search" ]] && continue
    echo "Googling... $search"
    (
      claude -p "web_search for <query>$search</query> and summarize the results" --allowedTools="web_search" > "$tmpdir/result_$i.txt"
    ) &
    pids+=($!)
    ((i++))
  done

  for pid in "${pids[@]}"; do wait "$pid"; done

  local results=""
  for file in "$tmpdir"/result_*.txt; do results+=$(cat "$file"); results+=$'\n'; done
  local final_report
  final_report=$(claude -p "Write a blog post based on these results for <query>$search_query</query>: $results")
  echo "$final_report"
}

#### Claude helpers
claude_chain() {
  local -a c=(claude --permission-mode acceptEdits -p)
  local m='then git commit'
  local p="$*"
  "${c[@]}" "$p, $m" && "${c[@]}" "Review and improve latest commit based on '$p', $m"
}

claudepool() {
  claude --append-system-prompt "Talk like a caffeinated Deadpool with sadistic commentary and comically PG-13 rated todo lists."
}

#### Obsidian/Knowledge Management
organize() {
  local system_prompt=$(cat <<'EOF'
You are an expert obsidian project organizer. Follow:
1) Shallow folders; organize via links & tags
2) Clear descriptive titles; remove dates
3) Promote clusters to MOC hubs; review weekly
Use 5+ subagents. Commit frequently.
EOF
)
  ENABLE_BACKGROUND_TASKS=1 claude --model opus --dangerously-skip-permissions --append-system-prompt "$system_prompt" -p "Organize this project." --output-format stream-json --verbose
}

curate() {
  local system_prompt=$(cat <<'EOF'
You are an expert obsidian curator. Focus on Knowledge Paths/Hubs.
CRITICAL: Condense duplicates. Sync names/links with rg.
Steps: tree → rg → curate → commit/push. Use 3+ subagents.
EOF
)
  ENABLE_BACKGROUND_TASKS=1 claude --model opus --dangerously-skip-permissions --append-system-prompt "$system_prompt" -p "Curate this project." --output-format stream-json --verbose
}

verify() {
  local system_prompt=$(cat <<'EOF'
You verify files against the web.
Steps: tree → 3 random files → verify → fix/create → commit.
Add frontmatter "last-verified" and "## Verifications" with sources.
EOF
)
  ENABLE_BACKGROUND_TASKS=1 claude --model opus --dangerously-skip-permissions --append-system-prompt "$system_prompt" -p "Verify this project." --output-format stream-json --verbose
}

#### Research
research() {
  [[ $# -eq 0 ]] && { echo "Usage: research <topic1> [topic2] ..."; return 1; }
  local project_name="$(basename "$PWD")"
  for topic in "$@"; do
    echo "🔎 Researching '$topic' for '$project_name'..."
    local content
    content="$(claude --model opus --dangerously-skip-permissions -p "Expert technical researcher. Obsidian-ready markdown for '${topic}' aimed at TypeScript devs. Include headings, bullets, code, references.")"
    echo "$content" | basic-memory --project "$project_name" tool write-note --title "$topic" --folder "research"
  done
  basic-memory --project "$project_name" tool recent-activity --timeframe 1d
}

#### Quartz research helpers (container-use)
quartz_research() {
  local MCP_CONFIG=$(cat <<'EOF'
{
  "mcpServers": {
    "container-use": { "type": "stdio", "command": "container-use", "args": ["stdio"] }
  }
}
EOF
)
  [[ $# -eq 0 ]] && { echo "Usage: quartz_research <topic1> [topic2] ..."; return 1; }
  local project_name="$(basename "$PWD")"
  local quartz_prompt=$(cat <<'EOF'
TOOLS:
ALWAYS use ONLY Environments for ANY file/code/shell ops—NO EXCEPTIONS.
Do NOT install/use git cli via environment_run_cmd; use env tools.
You MUST tell the user to use: container-use log <env_id> and container-use checkout <env_id>.

OBJECTIVE:
For each topic, create/update Quartz Markdown notes for expert devs in ≤5 min reading.

HARD CONSTRAINTS:
1) Atomic commits (git add <file> && git commit -m "<slug>: <summary>")
2) "## Sources" list with full URLs
3) ≤400 lines per note
4) De-duplicate via grep before writing
5) Exactly three sub-agents: researcher, summarizer, note-writer
6) Stop when coverage ≥0.8 or 5 successive commits have <10 LOC

OUTPUT:
Return concise per-commit status lines:
[OK] <file_path> (<LOC_delta>) – <summary>
EOF
)
  for topic in "$@"; do
    echo "🧠 quartz_research → '$topic' in '$project_name'"
    ENABLE_BACKGROUND_TASKS=1 cl "$topic" \
      --model opus \
      --append-system-prompt "$quartz_prompt" \
      --mcp-config "$MCP_CONFIG" \
      --print | claude --print --append-system-prompt "Merge using git checkout main then container-use merge <branch>"
  done
}

basic_memory_consistency() {
  local project_name="$(basename "$PWD")"
  { bm project add "$project_name" . 2>&1 || true; } | grep -qi "already exists" && echo "Already exists, continuing..."
  local bm_prompt=$(cat <<'EOF'
SYSTEM:
You are Basic‑Memory‑Agent v2 operating in "$project_name".
OBJECTIVE: Ensure consistency, organization, metadata across notes.

CONSTRAINTS:
1) Atomic commits
2) Use MCP tools (basic-memory) only
3) ≤400 lines per file
4) Shallow hierarchy: notes/, docs/, research/
5) Stop when clean scan has no inconsistencies

OUTPUT:
[OK] <action> <file_path> – <summary>
EOF
)
  ENABLE_BACKGROUND_TASKS=1 claude \
    --model opus \
    --dangerously-skip-permissions \
    --allowedTools="run_terminal_cmd" \
    --append-system-prompt "$bm_prompt" \
    -p "$topic" \
    --output-format stream-json \
    --verbose \
    --mcp-config "{\"mcpServers\":{\"basic-memory\":{\"command\":\"bm\",\"args\":[\"--project\",\"$project_name\",\"mcp\"]}}}"
}

#### Quartz task queue
export QUARTZ_QUEUE_DIR="$HOME/.quartz_research_queue"
export QUARTZ_QUEUE_FILE="$QUARTZ_QUEUE_DIR/queue.txt"
export QUARTZ_QUEUE_LOCK="$QUARTZ_QUEUE_DIR/lock"
export QUARTZ_QUEUE_PID="$QUARTZ_QUEUE_DIR/worker.pid"
mkdir -p "$QUARTZ_QUEUE_DIR"

_quartz_research_worker() {
  while true; do
    local job
    job=$(flock -x "$QUARTZ_QUEUE_LOCK" -c '
      if [ -s "$QUARTZ_QUEUE_FILE" ]; then
        head -n1 "$QUARTZ_QUEUE_FILE"
        tail -n +2 "$QUARTZ_QUEUE_FILE" > "$QUARTZ_QUEUE_FILE.tmp"
        mv "$QUARTZ_QUEUE_FILE.tmp" "$QUARTZ_QUEUE_FILE"
      fi
    ')
    [[ -z $job ]] && { rm -f "$QUARTZ_QUEUE_PID"; exit 0; }
    local dir=${job%%|*} topic=${job#*|}
    ( cd "$dir" && quartz_research "$topic" )
  done
}

quartz_research_queue() {
  [[ $# -eq 0 ]] && { echo "Usage: quartz_research_queue <topic1> [topic2] ..."; return 1; }
  local dir="$PWD"
  for topic in "$@"; do printf '%s|%s\n' "$dir" "$topic" >> "$QUARTZ_QUEUE_FILE"; done
  echo "🗂️  Queued: $*"
  if ! { [ -f "$QUARTZ_QUEUE_PID" ] && kill -0 "$(cat "$QUARTZ_QUEUE_PID")" 2>/dev/null; }; then
    _quartz_research_worker &!
    echo $! > "$QUARTZ_QUEUE_PID"
    echo "⏳ Worker started (PID $(cat "$QUARTZ_QUEUE_PID"))."
  fi
}

quartz_queue_status() { echo "📋 Pending jobs:"; awk -F'|' '{printf "  • %s — %s\n",$1,$2}' "$QUARTZ_QUEUE_FILE" 2>/dev/null || echo "  (empty)"; }
quartz_queue_cancel_all() { : > "$QUARTZ_QUEUE_FILE" && echo "🚮 Cleared the queue."; }

#### Deepwiki course builder
course_builder_plan() {
  local MCP_CONFIG=$(cat <<'EOF'
{
  "mcpServers": {
    "deepwiki": { "type": "sse", "url": "https://mcp.deepwiki.com/sse" }
  }
}
EOF
)
  local prompt=$(cat <<'EOF'
# Create a plan from the user's request
## Prepare
Use mcp__deepwiki__ask_question in "badass-courses/course-builder" repo.
## Plan Format
- Markdown; "goal" as H1
- Each step as a commit message
- Verification steps; exact file paths and sections; explicit changes
EOF
)
  cl --system-prompt "$prompt" "$@"
}

course_builder_claude() { claude "$(ask_course_builder "$@")"; }

#### Container-use/Claude harness
cl() {
  local system_prompt=$(cat <<'EOF'
ALWAYS use ONLY Environments for ANY file/code/shell ops—NO EXCEPTIONS.
Do NOT install/use git cli via environment_run_cmd; use env tools.
Tell the user: container-use log <env_id> and container-use checkout <env_id>.
EOF
)
  local allowed_tools=$(cat <<'EOF' | tr '\n' ',' | sed 's/,$//'
mcp__container-use__environment_checkpoint
mcp__container-use__environment_create
mcp__container-use__environment_add_service
mcp__container-use__environment_file_delete
mcp__container-use__environment_file_list
mcp__container-use__environment_file_read
mcp__container-use__environment_file_write
mcp__container-use__environment_open
mcp__container-use__environment_run_cmd
mcp__container-use__environment_update
Web
EOF
)
  local append_user_prompt=$(cat <<'EOF'
Before you begin:
1) use container-use to run commands
2) use conventional commit messages
EOF
)
  trap 'claude mcp remove container-use 2>/dev/null || true' EXIT ERR
  claude mcp add container-use -- container-use stdio || echo "container-use already installed"
  local improved_prompt="$*\n\n$append_user_prompt"
  claude --allowedTools "$allowed_tools" \
    --dangerously-skip-permissions \
    --append-system-prompt "$system_prompt" \
    "$improved_prompt"
}

#### Prompt tooling
improve() {
  claude --append-system-prompt "$(cat ~/.claude/prompts/improve.md)" "$@"
}

gist() { claude --print --settings "$HOME/.claude-settings/gist.json" "Create a gist of the following: $@"; }
github_tasks() { claude --settings "$HOME/.claude-settings/github-tasks.json" "$@"; }
create_repo() { local args="${@:-Initialize a repository in: $(pwd)}"; claude --settings "$HOME/.claude-settings/repoinit.json" "$args"; }

# Claude shorthand variants
dopus() { claude --model opus --dangerously-skip-permissions "$@"; }
popus() { dopus "$(pbpaste) --- $@"; }
copus() { claude --dangerously-skip-permissions "$@" --continue; }
conpus() { claude --allowedTools mcp__container-use__environment_checkpoint,mcp__container-use__environment_create,mcp__container-use__environment_add_service,mcp__container-use__environment_file_delete,mcp__container-use__environment_file_list,mcp__container-use__environment_file_read,mcp__container-use__environment_file_write,mcp__container-use__environment_open,mcp__container-use__environment_run_cmd,mcp__container-use__environment_update --dangerously-skip-permissions "$@"; }

# Gemini helpers
vid() { with_gemini claude-video "$@"; }
gem() { with_gemini gemsum "$@"; }
add_bm() { local project_name="$(basename "$PWD")"; bm project add "$project_name" .; claude mcp add -t stdio basic-memory -- bm --project "$project_name/memory" mcp; }

# File / command helpers
filei() { { cat "$1"; echo "$2"; } | claude; }
filep() { { cat "$1"; echo "$2"; } | claude --print; }
cmdi() { { eval "$1"; echo "$2"; } | claude; }
cmdp() { { eval "$1"; echo "$2"; } | claude --print; }

# Codex helpers
dopex() { codex --dangerously-bypass-approvals-and-sandbox -c model_reasoning_effort=high "$@"; }
upai() { bun i -g @openai/codex@latest @anthropic-ai/claude-code@latest @github/copilot@latest; npm i -g @google/gemini-cli@latest; }

codex_continue() {
  local latest
  latest=$(find ~/.codex/sessions -type f -name '*.jsonl' -print0 | xargs -0 ls -t 2>/dev/null | head -n 1)
  [[ -z "$latest" ]] && { echo "No codex sessions found"; return 1; }
  echo "Resuming from: $latest"
  codex --config experimental_resume="$latest" "$@"
}

cload() { local context=$(find ai -type f -name "*.md" -exec cat {} \;); claude --append-system-prompt "$context" "$@"; }
backlog_next() { dopus "Read the next task from the backlog. Follow git flow best practices and create a branch, work the task, then commit/push/PR using gh."; }

learn() { claude --settings '{"outputStyle": "interactive-doc-learner", "permissions": {"allow": ["Bash(curl -sL \"https://into.md:*\")"]}}' "$@"; }

# Image generation
imagegen() { gemini "/generate $@" -y; }
imagegen_clipboard() { gemini "Use the /generate command to generate: <image_prompt> $@ </image_prompt>; then copy the image to the clipboard" -y; }
gemini_plan() { local input="$@"; [ -p /dev/stdin ] && input="$(cat) $input"; gemini "Create and output a plan for: $input"; }

claude_qa() { claude --append-system-prompt "$(cat qa.md)" "$@"; }

commit() { claude --dangerously-skip-permissions "Review the unstaged and staged changes. Then use a fix or feat conventional commit for the changes. If needed, git pull and rebase." --print --verbose; }
push() { claude --dangerously-skip-permissions "Review the commited changes. If everything looks good, the git push the changes. If the push fails for any reason, explain in detail" --print --verbose; }
claude2gemini() {
  claude --print --output-format json --max-turns 1 "$@" \
  | jq -r '.text | gsub("\\s+"; " ")' \
  | gemini -y "Use the /generate command to create this image"
}

# Short aliases
unalias h 2>/dev/null
h() { claude --model haiku "$@"; }

unalias x 2>/dev/null
x() { claude --dangerously-skip-permissions "$@"; }
dex() { codex --dangerously-bypass-approvals-and-sandbox "$@"; }
xcon() { claude --dangerously-skip-permissions --continue "$@"; }
xres() { claude --dangerously-skip-permissions --resume "$@"; }
xfor() { claude --dangerously-skip-permissions --resume --fork-session "$@"; }

unalias cc 2>/dev/null
cc() { claude "$@"; }

unalias cdi 2>/dev/null
cdi() { claude --append-system-prompt "$(files ai/diagrams/**/*.md)"; }

inspiration() {
  claude --system-prompt "You are an inspirational speaker who comes up with 5 ideas for the user's topic" "$@"
}

diagram-create() {
  claude --allowed-tools "Skill(diagram)" --system-prompt "You are an expert of the Skill(diagram) tool. You create diagrams based on the user's prompt." "$@"
}

chrome-devtools() {
  local _settings="$HOME/.claude/settings/settings.chrome-devtools.json"
  local _mcp_config="$HOME/.claude/mcp/mcp.chrome-devtools.json"
  echo "$_settings"
  echo "$_mcp_config"
  claude --settings "$_settings" --mcp-config "$_mcp_config" --system-prompt "You are an expert of the Skill(chrome-devtools) tool. Connect to the given URL and ask the user what they want to do." "$@"
}

cont() { claude --continue "$@"; }
resu() { claude --resume "$@"; }

brainpick() {
  claude \
  --setting-sources "" \
  --settings '{"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "echo \"Remember to always use the AskUserQuestion tool.\""}]}]}}'\
  --model haiku \
  --system-prompt "You are an expert in helping the user clarify their intentions by asking thoughtful, targeted questions.
Your goal is to surface the user's underlying ideas, goals, and preferences—not to decide for them.
Let the user think. Ask one question at a time. Guide, don't lead." \
  "$@"
}

news() {
  local slugified_query=$(echo "$@" | slugify)
  local file_name="$(date +"%Y-%m-%d-%H-%M")-$slugified_query.md"
  local output_file="$(pwd)/$file_name"
  local system_prompt="You're an expert researcher and summarizer on the latest news."
  local prompt="## Critical Steps
Step 1: Research: \"$@\"
Step 2: Write a summary to $file_name"
  local allowed_tools="WebSearch,WebFetch,Write(./$file_name),Read(./$file_name)"
  echo "system_prompt: $system_prompt"
  echo "allowed_tools: $allowed_tools"
  echo "output_file: $output_file"
  echo "prompt: $prompt"
  claude --setting-sources="" --model=haiku --system-prompt="$system_prompt" --allowedTools="$allowed_tools" "$prompt"
}

best-practices() {
  local slugified_query=$(echo "$@" | slugify)
  local current_date=$(date +"%Y-%m-%d")
  local file_name="$(date +"%Y-%m-%d-%H-%M")-$slugified_query.md"
  local output_file="$(pwd)/$file_name"
  local system_prompt="You're an expert in researching the latest coding best practices."
  local prompt="The current date is $current_date. We're looking for the absolute latest best practices for the following files: \"$@\".

Ignore any advice that is over a year old.

## Critical Steps
Step 1: Using only the WebSearch and WebFetch tools, research the best practices for the files listed here: \"$@\".
Step 2: Write a summary to $file_name"
  local allowed_tools="WebSearch,WebFetch"
  echo "system_prompt: $system_prompt"
  echo "allowed_tools: $allowed_tools"
  echo "output_file: $output_file"
  echo "prompt: $prompt"
  claude --setting-sources="" --model=haiku --system-prompt="$system_prompt" --allowedTools="$allowed_tools" "$prompt"
}

claude-demo() { claude "Write a poem about the following: $@"; }

goo() { gemini -m gemini-3-pro-preview "$@"; }

# =============================================================================
# Gemini Diagram Generator (nanobanana extension)
# =============================================================================
# Interactive diagram generation with style selection
# Usage: diagram [prompt] or just `diagram` for interactive mode

diagram() {
  command -v gemini &>/dev/null || { echo "gemini CLI not found"; return 1; }

  # Diagram types
  local -a types=(
    "flowchart:Process flows, decision trees, workflows"
    "architecture:System architecture, microservices, infrastructure"
    "sequence:Sequence diagrams, API interactions"
    "database:Database schemas, entity relationships"
    "network:Network topology, server configurations"
    "wireframe:UI/UX mockups, page layouts"
    "mindmap:Concept maps, idea hierarchies"
  )

  # Visual styles
  local -a styles=(
    "professional:Clean corporate look"
    "clean:Minimalist design"
    "hand-drawn:Sketch-like appearance"
    "technical:Engineering blueprint style"
  )

  local selected_type selected_style prompt

  # Select type
  if command -v fzf &>/dev/null; then
    selected_type=$(printf '%s\n' "${types[@]}" | fzf --height 40% --reverse \
      --delimiter=':' --with-nth=1 \
      --preview='echo {2}' --preview-window=up:1 \
      --header="Select diagram type" | cut -d: -f1)
  else
    echo "Select diagram type:"
    select opt in "${types[@]%%:*}"; do
      selected_type="$opt"
      break
    done
  fi
  [[ -z "$selected_type" ]] && { echo "Cancelled"; return 0; }

  # Select style
  if command -v fzf &>/dev/null; then
    selected_style=$(printf '%s\n' "${styles[@]}" | fzf --height 40% --reverse \
      --delimiter=':' --with-nth=1 \
      --preview='echo {2}' --preview-window=up:1 \
      --header="Select visual style" | cut -d: -f1)
  else
    echo "Select style:"
    select opt in "${styles[@]%%:*}"; do
      selected_style="$opt"
      break
    done
  fi
  [[ -z "$selected_style" ]] && { echo "Cancelled"; return 0; }

  # Get prompt (from args or interactive)
  if [[ $# -gt 0 ]]; then
    prompt="$*"
  else
    echo -n "Describe your diagram: "
    read -r prompt
  fi
  [[ -z "$prompt" ]] && { echo "No description provided"; return 1; }

  # Build and execute command
  local cmd="/diagram \"$prompt\" --type=$selected_type --style=$selected_style"
  echo "Running: gemini --yolo '$cmd'"
  gemini --yolo "$cmd"
  # Open latest generated diagram
  local latest=$(ls -t ~/nanobanana-output/*.png ./nanobanana-output/*.png 2>/dev/null | head -1)
  [[ -n "$latest" ]] && open "$latest"
}

# Quick diagram variants for common types
diagram-flow() { gemini --yolo "/diagram \"$*\" --type=flowchart --style=professional" && _diagram_open; }
diagram-arch() { gemini --yolo "/diagram \"$*\" --type=architecture --style=technical" && _diagram_open; }
diagram-seq() { gemini --yolo "/diagram \"$*\" --type=sequence --style=clean" && _diagram_open; }
diagram-db() { gemini --yolo "/diagram \"$*\" --type=database --style=professional" && _diagram_open; }
diagram-wire() { gemini --yolo "/diagram \"$*\" --type=wireframe --style=hand-drawn" && _diagram_open; }

# Helper to open latest diagram
_diagram_open() {
  local latest=$(ls -t ~/nanobanana-output/*.png ./nanobanana-output/*.png 2>/dev/null | head -1)
  [[ -n "$latest" ]] && open "$latest"
}

github-issue-create() {
  claude --settings "$HOME/.claude/settings/settings.github.json" --system-prompt "Load the Skill(github) and load the referenced CREATE_ISSUE.md file to create an issue for the following" "$@"
}

plan() {
  local files=(ai/diagrams/**/*.md(N))
  if [[ ${#files[@]} -gt 0 ]]; then
    local prompt_content="<diagrams>$(files ${files[@]})</diagrams>"
    claude --permission-mode "plan" --append-system-prompt "$prompt_content" "$@"
  else
    claude --permission-mode "plan" "$@"
  fi
}
