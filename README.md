# macOS Dotfiles

Configuration files for macOS, organized in `~/.config` following the XDG Base Directory specification.

## Zsh Setup (with Oh My Zsh)

This setup moves all zsh configuration to `~/.config/zsh/` while keeping Oh My Zsh in its default location.

### Quick Install

```bash
# 1. Clone this repo to ~/.config
git clone https://github.com/johnlindquist/config.git ~/.config

# 2. Run the zsh installer
~/.config/zsh/install.sh

# 3. Restart your shell
exec zsh
```

### Manual Setup

If you prefer to set it up manually:

**1. Create `~/.zshenv`** (the only file needed in your home directory):

```bash
cat > ~/.zshenv << 'EOF'
# Bootstrap ZDOTDIR for XDG-compliant zsh config
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
EOF
```

**2. Install Oh My Zsh** (if not already installed):

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Oh My Zsh stays at `~/.oh-my-zsh` - this setup works with it there.

**3. Restart your shell:**

```bash
exec zsh
```

### How It Works

```
~/.zshenv                        # Bootstrap (sets ZDOTDIR, only file in $HOME)
~/.oh-my-zsh/                    # Oh My Zsh (unchanged, default location)
~/.config/zsh/
├── .zshenv                      # XDG environment variables
├── .zshrc                       # Main config (loads Oh My Zsh)
├── conf.d/                      # Modular configs (sourced alphabetically)
│   ├── 00-path.zsh             # PATH setup
│   ├── 10-aliases.zsh          # Aliases
│   ├── 20-1password.zsh        # 1Password CLI integration
│   ├── 30-git.zsh              # Git helpers
│   └── 40-ai.zsh               # AI CLI tools
├── local.zsh                    # Machine-specific config (gitignored)
└── install.sh                   # Installer script
```

### Adding Your Own Config

- **Aliases**: Edit `~/.config/zsh/conf.d/10-aliases.zsh`
- **Machine-specific**: Create `~/.config/zsh/local.zsh` (gitignored)
- **New module**: Create `~/.config/zsh/conf.d/XX-name.zsh`

Files in `conf.d/` are sourced in alphabetical order - use numeric prefixes to control load order.

### Dependencies

The installer will prompt to install these via Homebrew:

| Tool | Purpose |
|------|---------|
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter cd (`z` command) |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [bat](https://github.com/sharkdp/bat) | Better cat |
| [eza](https://github.com/eza-community/eza) | Better ls |

### Migrating from Traditional Setup

If you have an existing `~/.zshrc`:

1. Run `~/.config/zsh/install.sh`
2. Copy any custom config to `~/.config/zsh/local.zsh`
3. Remove or rename `~/.zshrc` (no longer needed)

## Other Configurations

This repo also includes configs for:

- **Karabiner** - Keyboard customization
- **WezTerm** - Terminal emulator
- **Yabai** - Window management (scripts in `scripts/`)
- **Zed** - Editor settings

## License

MIT
