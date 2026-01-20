# Terminal integration (WezTerm, iTerm2, etc.)
# OSC 7 - Report current working directory to terminal emulator
# This enables tab titles and status bar to show the current directory

# Disable "You have new mail" notification
unset MAILCHECK

_osc7_cwd() {
  printf '\033]7;file://%s%s\033\\' "${HOST}" "${PWD}"
}

# Hook into directory changes
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _osc7_cwd

# Run on shell startup
_osc7_cwd
