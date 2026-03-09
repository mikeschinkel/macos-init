#!/bin/sh
set -eu

mode="${1:-}"
window_id="${2:-}"

if [ -z "$mode" ] || [ -z "$window_id" ]; then
  tmux display-message "Swap failed: missing mode or window."
  exit 1
fi

session_id="$(tmux display-message -p -t "$window_id" "#{session_id}")"
current_index="$(tmux display-message -p -t "$window_id" "#{window_index}")"

prev_index=""
next_index=""

for idx in $(tmux list-windows -t "$session_id" -F "#{window_index}" | sort -n); do
  if [ "$idx" -lt "$current_index" ]; then
    prev_index="$idx"
    continue
  fi

  if [ "$idx" -gt "$current_index" ] && [ -z "$next_index" ]; then
    next_index="$idx"
  fi
done

case "$mode" in
  left)
    if [ -z "$prev_index" ]; then
      tmux display-message "Already at leftmost window."
      exit 0
    fi
    target_index="$prev_index"
    ;;
  right)
    if [ -z "$next_index" ]; then
      tmux display-message "Already at rightmost window."
      exit 0
    fi
    target_index="$next_index"
    ;;
  *)
    tmux display-message "Swap failed: invalid direction '$mode'."
    exit 1
    ;;
esac

# Make behavior deterministic: operate on the clicked window, not current focus.
tmux select-window -t "$window_id"
tmux swap-window -s "$window_id" -t "${session_id}:${target_index}"
tmux select-window -t "$window_id"
