# Zsh Configuration

XDG-compliant zsh setup with modular configuration and 1Password integration.

## Quick Start

```bash
# Clone the repo (or just this zsh directory)
git clone https://github.com/YOUR_USERNAME/dotfiles ~/.config

# Run the installer
~/.config/zsh/install.sh

# Start a new shell
exec zsh
```

## Structure

```
~/.zshenv                        # Bootstrap (only file in $HOME)
~/.config/zsh/
├── .zshenv                      # XDG environment setup
├── .zshrc                       # Main configuration
├── conf.d/                      # Modular configs (sourced alphabetically)
│   ├── 00-path.zsh             # PATH and environment
│   ├── 10-aliases.zsh          # Aliases and small functions
│   ├── 20-1password.zsh        # 1Password integration
│   ├── 30-git.zsh              # Git helpers
│   ├── 40-ai.zsh               # AI CLI helpers (Claude, Gemini, etc.)
│   └── 50-personas.zsh         # Code review personas
├── functions/                   # Autoloaded functions
├── local.zsh                    # Machine-specific config (gitignored)
├── local.zsh.example           # Template for local.zsh
├── zsh-gist                    # GitHub Gist helpers
├── install.sh                  # Installation script
└── README.md
```

## Features

### 1Password Integration

Centralized API key management with session caching:

```bash
# Fetch a key (cached for session)
opkey "GEMINI_API_KEY"

# Run command with key exported
with GEMINI_API_KEY gemini "hello"

# List available items
oplist

# Clear cache (after rotating keys)
opkey-clear
```

Customize item names in `local.zsh`:

```bash
export OP_GEMINI_ITEM="My Custom Gemini Key"
export OP_GITHUB_ITEM="GitHub Token"
```

### Modular Configuration

Add your own modules to `conf.d/`. Files are sourced in alphabetical order, so use numeric prefixes:

- `00-09`: Environment/PATH (sourced first)
- `10-19`: Aliases and basic functions
- `20-29`: Tool integrations (1Password, etc.)
- `30-39`: Git helpers
- `40-49`: Application-specific (AI, editors)
- `50+`: Everything else

### Machine-Specific Config

`local.zsh` is gitignored. Use it for:

- Machine-specific PATH additions
- Custom 1Password item names
- Personal aliases and shortcuts
- Tool configurations

Copy from `local.zsh.example` to get started.

## Dependencies

Installed automatically by `install.sh` on macOS:

| Tool | Purpose |
|------|---------|
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter cd command |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [bat](https://github.com/sharkdp/bat) | Better cat |
| [eza](https://github.com/eza-community/eza) | Better ls |
| [trash](https://github.com/ali-rantakari/trash) | Safe rm |

Optional:
- [Oh My Zsh](https://ohmyz.sh/) - Framework (expected at `~/.oh-my-zsh`)
- [Atuin](https://atuin.sh/) - Shell history sync
- [1Password CLI](https://developer.1password.com/docs/cli/) - API key management

## XDG Compliance

This setup follows the [XDG Base Directory Specification](https://wiki.archlinux.org/title/XDG_Base_Directory):

| Variable | Default | Usage |
|----------|---------|-------|
| `XDG_CONFIG_HOME` | `~/.config` | Configuration files |
| `XDG_DATA_HOME` | `~/.local/share` | Zsh history |
| `XDG_CACHE_HOME` | `~/.cache` | Completion cache |

The only file in `$HOME` is `.zshenv`, which bootstraps `ZDOTDIR`.

## Customization

### Adding Aliases

Edit `conf.d/10-aliases.zsh` or add to `local.zsh`.

### Adding a New Module

Create `conf.d/XX-name.zsh` where XX determines load order.

### Changing Default Editor

In `local.zsh`:

```bash
export EDITOR_CMD="code"  # or nvim, zed, etc.
```

## Migrating from Traditional Setup

If you have an existing `~/.zshrc`:

1. Run `install.sh`
2. Compare your old config with the new modular files
3. Move custom functions to `local.zsh` or appropriate `conf.d/` module
4. Delete or rename `~/.zshrc` (it's no longer used)

## License

MIT
