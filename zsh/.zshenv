# =============================================================================
# Zsh Environment Bootstrap
# =============================================================================
# This file is sourced first by zsh. We use it to set ZDOTDIR so all other
# zsh config files can live in ~/.config/zsh/ (XDG-compliant).
#
# NOTE: A minimal ~/.zshenv in $HOME sources this file. That's the ONLY
# zsh-related file needed in $HOME.
# =============================================================================

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Tell zsh where to find its config
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# History in XDG-compliant location
export HISTFILE="$XDG_DATA_HOME/zsh/history"
mkdir -p "$(dirname "$HISTFILE")" 2>/dev/null
