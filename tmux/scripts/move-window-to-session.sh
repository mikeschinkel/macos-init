#!/bin/sh
set -eu

window_id="${1:-}"
target_session="${2:-}"

if [ -z "$window_id" ] || [ -z "$target_session" ]; then
  tmux display-message "Move window failed: missing window or session target."
  exit 1
fi

tmux move-window -s "$window_id" -t "$target_session"
tmux switch-client -t "$target_session"
tmux select-window -t "$window_id"
