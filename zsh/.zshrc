# =============================================================================
# John's Zsh Configuration (XDG-compliant)
# =============================================================================
# All config lives in $ZDOTDIR (~/.config/zsh/)
# Modular configs in conf.d/ are sourced alphabetically
# Machine-specific overrides go in local.zsh (.gitignored)
# =============================================================================

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

# zoxide directory jumping
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

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

# Custom user functions (legacy location)
[[ -f ~/.zsh/custom/functions.zsh ]] && source ~/.zsh/custom/functions.zsh
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"

# Gist functions
[[ -f ~/.zsh-gist ]] && source ~/.zsh-gist
[[ -f "$ZDOTDIR/zsh-gist" ]] && source "$ZDOTDIR/zsh-gist"

#### 8) Tmux (only reload if inside tmux)
[[ -n "$TMUX" ]] && tmux source-file ~/.tmux.conf 2>/dev/null
