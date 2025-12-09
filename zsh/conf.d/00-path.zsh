# =============================================================================
# PATH Configuration
# =============================================================================
# Use zsh's unique path array to avoid duplicates automatically.
# Machine-specific paths can be added in local.zsh
# =============================================================================

typeset -U path

# Configurable versions (override in local.zsh)
: "${NODE_VERSION:=23.6.1}"
: "${HOMEBREW_PREFIX:=/opt/homebrew}"

# Common homes
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

# Suppress Python deprecation warnings
export PYTHONWARNINGS=ignore::DeprecationWarning

# Build PATH with highest-priority tools first
path=(
  # Node/pnpm/bun (highest priority)
  "$PNPM_HOME"
  "$HOME/Library/pnpm/nodejs/${NODE_VERSION}/bin"
  "$BUN_INSTALL/bin"

  # Homebrew
  "$HOMEBREW_PREFIX/opt/trash/bin"  # keg-only
  "$HOMEBREW_PREFIX/bin"
  /usr/local/bin
  /usr/bin
  /bin

  # User tools
  "$HOME/.local/bin"
  "$HOME/.ma"

  # Keep existing PATH entries
  $path
)

export PATH="${(j/:/)path}"

# Ensure PNPM stays at high precedence
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
