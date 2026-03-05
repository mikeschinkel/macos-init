#!/bin/sh
set -eu

CHEATSHEET="${HOME}/.init/tmux/tmux-cheatsheet.txt"

# Add a one-column left margin and hide the default less footer prompt.
sed 's/^/ /' "$CHEATSHEET" | less -R -P ' '
