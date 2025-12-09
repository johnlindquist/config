# =============================================================================
# John's Zsh Configuration (XDG-compliant)
# =============================================================================
# All config lives in $ZDOTDIR (~/.config/zsh/)
# Modular configs in conf.d/ are sourced alphabetically
# Machine-specific overrides go in local.zsh (.gitignored)
# =============================================================================

#### 0) Early PATH setup (needed for tool detection before conf.d loads)
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

#### 1) Oh My Zsh
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# Override Oh My Zsh's HISTFILE to XDG location
export HISTFILE="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")" 2>/dev/null

#### 2) Completions (cached for faster startup)
fpath+=("$ZDOTDIR/functions" ~/.zfunc)
autoload -Uz compinit
if [[ -n $ZDOTDIR/.zcompdump(#qN.mh+24) ]]; then
  compinit -d "$ZDOTDIR/.zcompdump"
else
  compinit -C -d "$ZDOTDIR/.zcompdump"
fi

#### 3) Shell enhancements
# Atuin (better history)
[[ -f "$HOME/.atuin/bin/env" ]] && . "$HOME/.atuin/bin/env" && eval "$(atuin init zsh)"

# fzf fuzzy finder
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# zoxide directory jumping (z = interactive with fzf, j = quick jump)
if command -v zoxide &>/dev/null; then
  # Configure fzf options for zoxide
  export _ZO_FZF_OPTS="--height 40% --layout=reverse --border --preview 'ls -la {2..}' --preview-window=right:40%"

  # Initialize zoxide (creates __zoxide_z and __zoxide_zi functions)
  eval "$(zoxide init zsh --no-cmd)"

  # z = always interactive with fzf preview
  function z() {
    __zoxide_zi "$@"
  }

  # t = interactive jump that also opens the directory in Cursor
  function t() {
    __zoxide_doctor
    local result
    result="$(\command zoxide query --interactive -- "$@")" || return $?
    __zoxide_cd "${result}" || return $?
    if command -v cursor &>/dev/null; then
      cursor "${result}"
    else
      echo "cursor not found in PATH"
    fi
  }

  # j = quick jump (non-interactive, for when you know where you're going)
  function j() {
    __zoxide_z "$@"
  }

fi

#### 4) Report slow commands
REPORTTIME=5

#### 5) Load modular configs from conf.d/
# Files are sourced in alphabetical order (use numeric prefixes)
for conf in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$conf"
done

#### 6) Load machine-specific local config (not version controlled)
[[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"

#### 7) External tool configs
# 1Password plugins
[[ -f "$HOME/.config/op/plugins.sh" ]] && source "$HOME/.config/op/plugins.sh"

# Bun completions
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

# Custom user functions
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"

# Gist functions
[[ -f "$ZDOTDIR/zsh-gist" ]] && source "$ZDOTDIR/zsh-gist"

#### 8) Tmux (only reload if inside tmux)
[[ -n "$TMUX" ]] && tmux source-file ~/.tmux.conf 2>/dev/null

# bun completions
[ -s "/Users/johnlindquist/.bun/_bun" ] && source "/Users/johnlindquist/.bun/_bun"

# mdflow: Treat .md files as executable agents
alias -s md='_handle_md'
_handle_md() {
  local input="$1"
  shift

  # Resolve input: URLs pass through, files check current dir then PATH
  local resolved=""
  if [[ "$input" =~ ^https?:// ]]; then
    # URL - pass through as-is
    resolved="$input"
  elif [[ -f "$input" ]]; then
    resolved="$input"
  else
    # Search PATH for the .md file
    local dir
    for dir in ${(s/:/)PATH}; do
      if [[ -f "$dir/$input" ]]; then
        resolved="$dir/$input"
        break
      fi
    done
  fi

  if [[ -z "$resolved" ]]; then
    echo "File not found: $input (checked current dir and PATH)"
    return 1
  fi

  # Pass resolved file/URL and any remaining args to handler
  if command -v mdflow &>/dev/null; then
    mdflow "$resolved" "$@"
  else
    echo "mdflow not installed."
    read -q "REPLY?Would you like to run \`bun add -g mdflow\` now? [y/N] "
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      bun add -g mdflow
      echo
      read -q "REPLY?Would you like to attempt to run this again? [y/N] "
      echo
      if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        mdflow "$resolved" "$@"
      fi
    else
      return 1
    fi
  fi
}

# mdflow: Add agent directories to PATH
# User agents (~/.mdflow) - run agents by name from anywhere
export PATH="$HOME/.mdflow:$PATH"

# Project agents (.mdflow) - auto-add local .mdflow/ to PATH when entering directories
# This function runs on each directory change to update PATH dynamically
_mdflow_chpwd() {
  # Remove project .mdflow paths from PATH, but keep ~/.mdflow (user agents)
  # Project paths: /path/to/project/.mdflow (4+ segments)
  # User path: /Users/name/.mdflow (3 segments) - keep this one
  PATH=$(echo "$PATH" | tr ':' '\n' | grep -vE '^(/[^/]+){4,}/\.mdflow$' | tr '\n' ':' | sed 's/:$//')
  # Add current directory's .mdflow if it exists
  if [[ -d ".mdflow" ]]; then
    export PATH="$PWD/.mdflow:$PATH"
  fi
}

# Hook into directory change (zsh)
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _mdflow_chpwd
fi

# Hook into directory change (bash)
if [[ -n "$BASH_VERSION" ]]; then
  PROMPT_COMMAND="_mdflow_chpwd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Run once on shell start
_mdflow_chpwd

# mdflow: Short alias for mdflow command
alias md='mdflow'
