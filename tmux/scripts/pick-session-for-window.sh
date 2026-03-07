#!/bin/sh
set -eu

mode="${1:-}"
window_id="${2:-}"

if [ -z "$mode" ] || [ -z "$window_id" ]; then
  tmux display-message "Pick session failed: missing mode or window."
  exit 1
fi

case "$mode" in
  move) action_script="$HOME/.init/tmux/scripts/move-window-to-session.sh" ;;
  send) action_script="$HOME/.init/tmux/scripts/send-window-to-session.sh" ;;
  *)
    tmux display-message "Pick session failed: invalid mode '$mode'."
    exit 1
    ;;
esac

# Ensure chooser appears in the window the menu was opened for.
tmux select-window -t "$window_id"
tmux choose-tree -sZ -O name "run-shell '$action_script $window_id %%'"
