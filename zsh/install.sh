#!/usr/bin/env bash
# =============================================================================
# Zsh Configuration Installer
# =============================================================================
# Sets up XDG-compliant zsh configuration with a single file in $HOME
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHENV_CONTENT='# Bootstrap ZDOTDIR for XDG-compliant zsh config
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"'

echo "🚀 Installing zsh configuration..."
echo "   Source: $SCRIPT_DIR"

# -----------------------------------------------------------------------------
# 1. Create ~/.zshenv bootstrap (only file needed in $HOME)
# -----------------------------------------------------------------------------
if [[ -f "$HOME/.zshenv" ]]; then
  if grep -q "ZDOTDIR" "$HOME/.zshenv"; then
    echo "✓  ~/.zshenv already configured"
  else
    echo "⚠️  ~/.zshenv exists but doesn't set ZDOTDIR"
    echo "   Backing up to ~/.zshenv.backup"
    cp "$HOME/.zshenv" "$HOME/.zshenv.backup"
    echo "$ZSHENV_CONTENT" > "$HOME/.zshenv"
    echo "✓  Updated ~/.zshenv"
  fi
else
  echo "$ZSHENV_CONTENT" > "$HOME/.zshenv"
  echo "✓  Created ~/.zshenv"
fi

# -----------------------------------------------------------------------------
# 2. Create XDG directories
# -----------------------------------------------------------------------------
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
echo "✓  Created XDG directories"

# -----------------------------------------------------------------------------
# 3. Create local.zsh from example if it doesn't exist
# -----------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/local.zsh" ]]; then
  if [[ -f "$SCRIPT_DIR/local.zsh.example" ]]; then
    cp "$SCRIPT_DIR/local.zsh.example" "$SCRIPT_DIR/local.zsh"
    echo "✓  Created local.zsh from template"
    echo "   → Edit $SCRIPT_DIR/local.zsh for machine-specific config"
  fi
else
  echo "✓  local.zsh already exists"
fi

# -----------------------------------------------------------------------------
# 4. Install dependencies (macOS with Homebrew)
# -----------------------------------------------------------------------------
if command -v brew &>/dev/null; then
  echo ""
  echo "📦 Checking dependencies..."

  deps=(zoxide fzf bat eza trash)
  missing=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "   Installing: ${missing[*]}"
    brew install "${missing[@]}"

    # Setup fzf key bindings if newly installed
    if [[ " ${missing[*]} " =~ " fzf " ]]; then
      "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    fi
  else
    echo "✓  All dependencies installed"
  fi
else
  echo ""
  echo "⚠️  Homebrew not found. Install these manually:"
  echo "   zoxide fzf bat eza trash"
fi

# -----------------------------------------------------------------------------
# 5. Handle legacy ~/.zshrc if it exists
# -----------------------------------------------------------------------------
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  echo ""
  echo "⚠️  Found existing ~/.zshrc (not a symlink)"
  echo "   The new config lives at $SCRIPT_DIR/.zshrc"
  echo "   Options:"
  echo "   1. Back it up:  mv ~/.zshrc ~/.zshrc.old"
  echo "   2. Delete it:   rm ~/.zshrc"
  echo "   3. Keep both (zsh will use ZDOTDIR config)"
fi

# -----------------------------------------------------------------------------
# 6. Handle legacy ~/.zsh directory if it exists
# -----------------------------------------------------------------------------
if [[ -d "$HOME/.zsh" && ! -L "$HOME/.zsh" ]]; then
  echo ""
  echo "⚠️  Found existing ~/.zsh directory"
  echo "   You may want to migrate useful functions to:"
  echo "   $SCRIPT_DIR/conf.d/ or $SCRIPT_DIR/local.zsh"
fi

# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------
echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Review/edit $SCRIPT_DIR/local.zsh"
echo "  2. Start a new terminal or run: exec zsh"
echo ""
echo "File structure:"
echo "  ~/.zshenv                    → Bootstrap (sets ZDOTDIR)"
echo "  ~/.config/zsh/.zshrc         → Main config"
echo "  ~/.config/zsh/conf.d/*.zsh   → Modular configs"
echo "  ~/.config/zsh/local.zsh      → Your machine-specific config"
