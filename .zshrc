# Fix PATH for core commands
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Start SSH agent and add keys
if [ -z "$SSH_AUTH_SOCK" ]; then
   # Check if ssh-agent is already running
   eval "$(ssh-agent -s)"
fi

# Add your SSH key if it's not already added
ssh-add -l &>/dev/null
if [ $? -eq 1 ]; then
    ssh-add ~/.ssh/id_ed25519 &>/dev/null
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Added by Windsurf
export PATH="/Users/johnlindquist/.codeium/windsurf/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/johnlindquist/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
alias code="/usr/local/bin/cursor"
alias cursor="/usr/local/bin/cursor "
unalias c 2>/dev/null
c() {
  if [ $# -eq 0 ]; then
    /usr/local/bin/cursor .  # Open current directory if no args
  else
    # If the first argument doesn't exist, decide whether to create a file or directory
    if [ ! -e "$1" ]; then
      # Check if it starts with a dot or contains a dot (likely a file)
      if [[ "$1" == .* || "$1" == *.* ]]; then
        touch "$1" # Create the file
      else
        mkdir -p "$1" # Create the directory
      fi
    fi
    /usr/local/bin/cursor "$@" # Open the specified path(s)
  fi
}
alias w="~/.codeium/windsurf/bin/windsurf"
alias ww="~/.codeium/windsurf/bin/windsurf ~/dev/windsurf"

alias z="/usr/local/bin/cursor ~/.zshrc"
alias k="/usr/local/bin/cursor ~/.config/karabiner.edn"
alias s="source ~/.zshrc"

unalias fix 2>/dev/null
unalias feat 2>/dev/null
unalias chore 2>/dev/null
unalias takeAndWindsurf 2>/dev/null
unalias push 2>/dev/null
cfix() {
  local scope="$1"
  local message="$2"
  git add . && git commit -m "fix($scope): $message"
}

# Git fix function for conventional commits
fix() {
  local scope="$1"
  local message="$2"
  git add . && git commit -m "fix($scope): $message" && git push
}

# Git chore function for conventional commits
chore() {
  local scope="$1"
  local message="$2"
  git add . && git commit -m "chore($scope): $message" && git push
}

# Git feat function for conventional commits
feat() {
  local scope="$1"
  local message="$2"
  git add . && git commit -m "feat($scope): $message" && git push
}

# Push function for "fix: tweak" message. No scope. Hardcoded message.
push() {
  git add . && git commit -m "fix: tweak" && git push
}

# Git chore function for conventional commits
chore() {
  local scope="$1"
  local message="$2"
  git add . && git commit -m "chore($scope): $message" && git push
}

takeAndWindsurf() {
  take "$1" && windsurf "$1"
}

alias pup="pnpm dlx npm-check-updates -i -p pnpm"

clone(){
  local repo="$1"
  local dir="${2:-${repo##*/}}"  # Use the second argument if provided, otherwise extract from repo
  gh repo clone "https://github.com/$repo" "$dir"
  w "$dir"
  cd "$dir"
  pnpm i
}

kdev(){
  cd ~/dev/kit
  pnpm build
  cd -
  pnpm dev
}

share-react-project() {
  if [[ -z "$1" ]]; then
    echo "Usage: share-react-project <project_name>"
    return 1
  fi

  local project_name="$1"
  local github_username=$(gh api /user --jq '.login')

  echo "Creating Vite project: $project_name"
  pnpm create vite "$project_name" --template react

  cd "$project_name"

  echo "Initializing Git repository"
  git init

  echo "Adding all files to Git"
  git add .

  echo "Creating initial commit"
  git commit -m "Initial commit"

  local codesandbox_link="https://codesandbox.io/p/github/${github_username}/${project_name}"

  echo "Adding CodeSandbox link to README.md"
  echo "" >> README.md
  echo "## CodeSandbox" >> README.md
  echo "[![Open in CodeSandbox](https://assets.codesandbox.io/github/button-edit-blue.svg)](${codesandbox_link})" >> README.md

  echo "Adding README.md to Git"
  git add README.md

  echo "Committing README.md changes"
  git commit -m "Add CodeSandbox link"

  echo "Creating GitHub repository: $github_username/$project_name"
  gh repo create "$github_username/$project_name" --public

  echo "Pushing to remote 'origin'"
  git push -u origin main

  echo "Project '$project_name' created successfully!"
  echo "GitHub repository: https://github.com/$github_username/$project_name"
  echo "CodeSandbox link: $codesandbox_link"

  # Ensure pnpm path has highest precedence
  export PATH="$PNPM_HOME:$PATH"
}

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/johnlindquist/.lmstudio/bin"


pinit23(){
  pnpm init # Create package.json
  pnpm pkg set type=module # Set type to module
  pnpm pkg set scripts.dev="node --env-file=.env --no-warnings index.ts" # Set dev script to run index.ts
  pnpm set --location project use-node-version 23.6.1    # Auto-install/use node 23.6.1
  pnpm add -D @types/node @tsconfig/node23 @tsconfig/strictest # Add tsconfig
  pnpm add dotenv # Add dotenv
  echo 'TEST_API_KEY=Successfully loaded .env' > .env # Create .env
  pnpm dlx gitignore Node # Create .gitignore
  echo '{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": ["@tsconfig/node23/tsconfig.json", "@tsconfig/strictest/tsconfig.json"]
}' > tsconfig.json # Create tsconfig.json
  echo 'declare global {
	namespace NodeJS {
		interface ProcessEnv {
			TEST_API_KEY: string;
		}
	}
}

console.log(`${process.env.TEST_API_KEY || "Failed to load .env"}`);' > index.ts # Create index.ts  
  mkdir logs
  pnpm dev # Run dev script
  git init
  git add .
  git commit -m "(feat):project setup"
}



ghsearch() {
  # Save original PATH
  local ORIGINAL_PATH="$PATH"
  
  # Set up logging
  local debug=1
  local timestamp=$(/bin/date +%Y%m%d-%H%M%S)
  local log_dir="$HOME/searches/logs"
  local log_file="$log_dir/ghsearch-$timestamp.log"
  
  # Ensure log directory exists
  /bin/mkdir -p "$log_dir" 2>/dev/null
  
  # Logging function
  log() {
    local level="$1"
    local message="$2"
    if [[ "$level" == "DEBUG" && "$debug" -eq 0 ]]; then
      return
    fi
    echo "[$level] $message" | /usr/bin/tee -a "$log_file"
  }
  
  log "DEBUG" "Starting ghsearch function"
  log "DEBUG" "Initial environment state:"
  log "DEBUG" "Command: ghsearch $*"
  log "DEBUG" "Original PATH: $ORIGINAL_PATH"
  
  # Set PATH to include necessary directories
  export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$ORIGINAL_PATH"
  log "DEBUG" "Current PATH: $PATH"
  
  # Get the search query
  local query="$*"
  if [ -z "$query" ]; then
    log "ERROR" "No search query provided"
    return 1
  fi
  
  log "INFO" "Processing query: $query"
  
  # Check for problematic characters
  if [[ "$query" =~ [^a-zA-Z0-9[:space:]/_.-] ]]; then
    log "WARN" "Query contains special characters that might need escaping: $query"
  fi
  
  # Create sanitized filename
  local sanitized_query=$(/bin/echo "$query" | /usr/bin/tr -c '[:alnum:]_-' '_' | /usr/bin/sed 's/_*$//')
  log "DEBUG" "Sanitized filename: $sanitized_query"
  
  # Set up results file
  local results_dir="$HOME/searches"
  local results_file="$results_dir/$sanitized_query-$timestamp.md"
  /bin/mkdir -p "$results_dir" 2>/dev/null
  
  log "INFO" "Will save results to: $results_file"
  
  # Check for required commands
  local gh_path=$(/usr/bin/which gh 2>/dev/null)
  local jq_path=$(/usr/bin/which jq 2>/dev/null)
  local curl_path=$(/usr/bin/which curl 2>/dev/null)
  
  log "DEBUG" "Found gh at: $gh_path"
  log "DEBUG" "Found jq at: $jq_path"
  log "DEBUG" "Found curl at: $curl_path"
  
  if [ -z "$gh_path" ] || [ -z "$jq_path" ] || [ -z "$curl_path" ]; then
    log "ERROR" "Missing required commands. Please install: gh, jq, curl"
    return 1
  fi
  
  # Execute GitHub search
  log "INFO" "Executing GitHub search: gh search code \"$query\" --json path,repository,url --limit 30"
  local search_output
  search_output=$(/opt/homebrew/bin/gh search code "$query" --json path,repository,url --limit 30)
  local gh_exit="$?"
  
  if [ "$gh_exit" -ne 0 ]; then
    log "ERROR" "GitHub search failed with exit code $gh_exit"
    log "ERROR" "Raw output: $search_output"
    return 1
  fi
  
  log "DEBUG" "gh exit code: $gh_exit"
  log "DEBUG" "gh raw output: $search_output"
  
  # Validate JSON output
  if ! /bin/echo "$search_output" | /opt/homebrew/bin/jq . >/dev/null 2>&1; then
    log "ERROR" "Invalid JSON response from GitHub search"
    log "ERROR" "Raw output: $search_output"
    return 1
  fi
  
  # Count results
  local result_count=$(/bin/echo "$search_output" | /opt/homebrew/bin/jq '. | length')
  log "DEBUG" "Found $result_count results"
  
  if [ "$result_count" -eq 0 ]; then
    log "INFO" "No results found"
    {
      /bin/echo "# GitHub Code Search Results"
      /bin/echo "Query: \`$query\`"
      /bin/echo "Date: $(/bin/date)"
      /bin/echo
      /bin/echo "No results found for this query."
    } > "$results_file"
    return 0
  fi
  
  # Process results
  log "INFO" "Processing search results..."
  
  {
    /bin/echo "# GitHub Code Search Results"
    /bin/echo "Query: \`$query\`"
    /bin/echo "Date: $(/bin/date)"
    /bin/echo
    /bin/echo "Found $result_count results. Showing code snippets containing your search terms."
    /bin/echo
    /bin/echo "## Results"
    /bin/echo
    
    /bin/echo "$search_output" | /opt/homebrew/bin/jq -r '.[] | "### [\(.repository.nameWithOwner)](\(.repository.url))\n\nFile: [\(.path)](\(.url))\n\n```" + (.path | match("\\.[a-zA-Z0-9]+$") | .string[1:] // "") + "\n# Content from \(.path):\n" + (.url | sub("github.com"; "raw.githubusercontent.com") | sub("/blob/"; "/")) + "\n"' | while read -r line; do
      if [[ "$line" =~ ^https ]]; then
        # This is a URL line, fetch the content
        content=$(/usr/bin/curl -s -L "$line")
        if [ -n "$content" ]; then
          /bin/echo "$content" | /usr/bin/awk '{printf "%4d: %s\n", NR, $0}' | /usr/bin/head -n 50
          if [ "$(/bin/echo "$content" | /usr/bin/wc -l)" -gt 50 ]; then
            /bin/echo "... (truncated, showing first 50 lines)"
          fi
        else
          /bin/echo "Failed to fetch content from $line"
        fi
        /bin/echo '```'
        /bin/echo
        /bin/echo "---"
        /bin/echo
      else
        /bin/echo "$line"
      fi
    done
  } > "$results_file"
  
  # Try to open in Cursor
  log "DEBUG" "Opening results in Cursor"
  if [ -f "$results_file" ]; then
    if ! /Applications/Cursor.app/Contents/MacOS/Cursor "$results_file" 2>/dev/null; then
      log "ERROR" "Failed to open results in Cursor"
      /bin/echo "You can open the results manually with: cursor '$results_file'"
    fi
  else
    log "ERROR" "Results file not found: $results_file"
  fi
  
  # Restore original PATH
  export PATH="$ORIGINAL_PATH"
  log "DEBUG" "Restored PATH: $PATH"
  
  log "DEBUG" "ghsearch function completed"
}

export PATH="/Users/johnlindquist/Library/pnpm/nodejs/23.6.1/bin:$PATH"
# bun completions
[ -s "/Users/johnlindquist/.bun/_bun" ] && source "/Users/johnlindquist/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# wtree: Create a new worktree for each given branch.
# Usage: wtree [ -p|--pnpm ] branch1 branch2 ...
#
# This function does the following:
#   1. Parses command-line arguments; if -p/--pnpm is provided, it will later run "pnpm install".
#   2. Determines the current branch and repository root.
#   3. Uses a fixed parent directory (~/dev) to house all worktree directories.
#   4. For each branch passed:
#        - If the branch does not exist, it is created from the current branch.
#        - It checks that a worktree for that branch does not already exist.
#        - It then creates a worktree in ~/dev using a naming convention: <repoName>-<branch>.
#        - If the install-deps flag is true, it runs "pnpm install" inside the new worktree.
#        - Finally, it either opens the new worktree via the custom "cursor" command (if defined)
#          or prints its path.
wtree() {
  # Flag to determine whether to run "pnpm install"
  local install_deps=false
  local branches=()

  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--pnpm)
        install_deps=true
        shift
        ;;
      *)
        branches+=("$1")
        shift
        ;;
    esac
  done

  # Ensure at least one branch name is provided.
  if [[ ${#branches[@]} -eq 0 ]]; then
    echo "Usage: wtree [ -p|--pnpm ] branch1 branch2 ..."
    return 1
  fi

  # Determine the current branch; exit if not in a git repository.
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD) || {
    echo "Error: Not a git repository."
    return 1
  }

  # Determine repository root and name.
  local repo_root repo_name
  repo_root=$(git rev-parse --show-toplevel) || {
    echo "Error: Cannot determine repository root."
    return 1
  }
  repo_name=$(basename "$repo_root")

  # Set fixed parent directory for worktrees.
  local worktree_parent="$HOME/dev"
  # Ensure the worktree parent directory exists.
  if [[ ! -d "$worktree_parent" ]]; then
    if ! mkdir -p "$worktree_parent"; then
      echo "Error: Failed to create worktree parent directory: $worktree_parent"
      return 1
    fi
  fi

  # Loop over each branch provided as argument.
  for branch in "${branches[@]}"; do
    # Define the target path using a naming convention: <repoName>-<branch>
    local target_path="$worktree_parent/${repo_name}-${branch}"
    
    echo "Processing branch: ${branch}"

    # Check if a worktree already exists at the target path.
    if git worktree list | grep -q "^${target_path}[[:space:]]"; then
      echo "Error: Worktree already exists at ${target_path}. Skipping branch '${branch}'."
      continue
    fi

    # If the branch does not exist, create it from the current branch.
    if ! git show-ref --verify --quiet "refs/heads/${branch}"; then
      echo "Branch '${branch}' does not exist. Creating it from '${current_branch}'..."
      if ! git branch "${branch}"; then
        echo "Error: Failed to create branch '${branch}'. Skipping."
        continue
      fi
    fi

    # Create the new worktree for the branch.
    echo "Creating worktree for branch '${branch}' at ${target_path}..."
    if ! git worktree add "$target_path" "${branch}"; then
      echo "Error: Failed to create worktree for branch '${branch}'. Skipping."
      continue
    fi

    # If the install flag is set, run "pnpm install" in the new worktree.
    if $install_deps; then
      echo "Installing dependencies in worktree for branch '${branch}'..."
      if ! ( cd "$target_path" && pnpm install ); then
        echo "Warning: Failed to install dependencies in '${target_path}'."
      fi
    fi

    # Optionally, open the worktree directory via a custom "cursor" command if available.
    if type cursor >/dev/null 2>&1; then
      cursor "$target_path"
    else
      echo "Worktree created at: ${target_path}"
    fi

    echo "Worktree for branch '${branch}' created successfully."
    echo "-----------------------------------------------------"
  done
}


# wtmerge: Merge changes from a specified worktree branch into main,
# then clean up all worktrees and delete their branches.
#
# Usage: wtmerge <branch-to-keep>
#
# This function does the following:
#   1. Verifies that the branch to merge (branch-to-keep) exists as an active worktree.
#   2. Checks for uncommitted changes in that worktree:
#        - If changes exist, it attempts to stage and commit them.
#        - It gracefully handles the situation where there are no changes.
#   3. Switches the current (main) worktree to the "main" branch.
#   4. Merges the specified branch into main, with proper error checking.
#   5. Uses "git worktree list" to retrieve all active worktrees (under ~/dev
#      and matching the naming pattern) and removes them.
#   6. Deletes each branch that was created for a worktree (skipping "main").
wtmerge() {
  # Ensure exactly one argument is passed: the branch to merge.
  if [ $# -ne 1 ]; then
    echo "Usage: wtmerge <branch-to-keep>"
    return 1
  fi

  local branch_to_keep="$1"

  # Determine the repository root and its name.
  local repo_root repo_name
  repo_root=$(git rev-parse --show-toplevel) || {
    echo "Error: Not a git repository."
    return 1
  }
  repo_name=$(basename "$repo_root")

  # Fixed parent directory where worktrees are located.
  local worktree_parent="$HOME/dev"

  # Retrieve all active worktrees (from git worktree list) that match our naming convention.
  local worktrees=()
  while IFS= read -r line; do
    # Extract the worktree path (first field)
    local wt_path
    wt_path=$(echo "$line" | awk '{print $1}')
    # Only consider worktrees under our fixed parent directory that match "<repo_name>-*"
    if [[ "$wt_path" == "$worktree_parent/${repo_name}-"* ]]; then
      worktrees+=("$wt_path")
    fi
  done < <(git worktree list)

  # Check that the target branch worktree exists.
  local target_worktree=""
  for wt in "${worktrees[@]}"; do
    if [[ "$wt" == "$worktree_parent/${repo_name}-${branch_to_keep}" ]]; then
      target_worktree="$wt"
      break
    fi
  done

  if [[ -z "$target_worktree" ]]; then
    echo "Error: No active worktree found for branch '${branch_to_keep}' under ${worktree_parent}."
    return 1
  fi

  # Step 1: In the target worktree, check for uncommitted changes.
  echo "Checking for uncommitted changes in worktree for branch '${branch_to_keep}'..."
  if ! ( cd "$target_worktree" && git diff --quiet && git diff --cached --quiet ); then
    echo "Changes detected in branch '${branch_to_keep}'. Attempting auto-commit..."
    if ! ( cd "$target_worktree" &&
            git add . &&
            git commit -m "chore: auto-commit changes in '${branch_to_keep}' before merge" ); then
      echo "Error: Auto-commit failed in branch '${branch_to_keep}'. Aborting merge."
      return 1
    else
      echo "Auto-commit successful in branch '${branch_to_keep}'."
    fi
  else
    echo "No uncommitted changes found in branch '${branch_to_keep}'."
  fi

  # Step 2: Switch to the main worktree (assumed to be the current directory) and check out main.
  echo "Switching to 'main' branch in the main worktree..."
  if ! git checkout main; then
    echo "Error: Failed to switch to 'main' branch."
    return 1
  fi

  # Step 3: Merge the target branch into main.
  echo "Merging branch '${branch_to_keep}' into 'main'..."
  if ! git merge "${branch_to_keep}" -m "feat: merge changes from '${branch_to_keep}'"; then
    echo "Error: Merge failed. Please resolve conflicts and try again."
    return 1
  fi

  # Step 4: Remove all worktrees that were created via wtree().
  echo "Cleaning up worktrees and deleting temporary branches..."
  for wt in "${worktrees[@]}"; do
    # Extract branch name from worktree path.
    local wt_branch
    wt_branch=$(basename "$wt")
    wt_branch=${wt_branch#${repo_name}-}  # Remove the repo name prefix

    echo "Processing worktree for branch '${wt_branch}' at ${wt}..."
    # Remove the worktree using --force to ensure removal.
    if git worktree remove "$wt" --force; then
      echo "Worktree at ${wt} removed."
    else
      echo "Warning: Failed to remove worktree at ${wt}."
    fi

    # Do not delete the 'main' branch.
    if [[ "$wt_branch" != "main" ]]; then
      if git branch -D "$wt_branch"; then
        echo "Branch '${wt_branch}' deleted."
      else
        echo "Warning: Failed to delete branch '${wt_branch}'."
      fi
    fi
  done

  echo "Merge complete: Branch '${branch_to_keep}' merged into 'main', and all worktrees cleaned up."
}
export PATH="$PATH":"$HOME/.pub-cache/bin"

# alias for "pkill Electron"
alias pke="pkill Electron"

# Ensure pnpm path has highest precedence
export PATH="$PNPM_HOME:$PATH"

export PATH="$HOME/.local/bin:$PATH"

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# Alias for managing dotfiles with git
alias config='/usr/bin/git --git-dir=/Users/johnlindquist/.config/.git --work-tree=/Users/johnlindquist'
