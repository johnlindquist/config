# Auto-attach to zellij is disabled per request. Re-enable by restoring the block below.
# if command -v zellij >/dev/null 2>&1 \
#   && [[ $- == *i* ]] \
#   && [[ -z "$ZELLIJ" && -z "$TMUX" ]]; then
#   if [[ -z "${ZELLIJ_AUTO_SESSION:-}" ]]; then
#     if [[ -n "${TTY:-}" ]]; then
#       ZELLIJ_AUTO_SESSION="auto-${TTY##*/}"
#     else
#       ZELLIJ_AUTO_SESSION="auto-$$"
#     fi
#   fi
#   zellij attach --create "$ZELLIJ_AUTO_SESSION"
# fi
