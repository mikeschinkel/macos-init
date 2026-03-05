#!/usr/bin/env zsh
# Shared, timestamped history and readable history helper.

export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=200000
export SAVEHIST=200000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS

_histtime_trim_ws() {
  local s="$1"

  # Trim leading and trailing whitespace.
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

_histtime_decode_cmd() {
  local cmd="$1"
  local nl=$'\n'
  local tab=$'\t'
  local cr=$'\r'

  # Decode zsh ANSI-C quoted fragments emitted by history rendering.
  cmd="${cmd//\$\'\\n\'/$nl}"
  cmd="${cmd//\$\'\\t\'/$tab}"
  cmd="${cmd//\$\'\\r\'/$cr}"

  # Also decode plain backslash escapes.
  cmd="${cmd//\\n/$nl}"
  cmd="${cmd//\\t/$tab}"
  cmd="${cmd//\\r/$cr}"

  print -r -- "$cmd"
}

histtime() {
  local n="${1:-50}"
  local first
  local line trimmed rest
  local num ts cmd part
  local -a cmd_lines
  local i

  # Compute first event index relative to current shell history list.
  first=$(( HISTCMD - n + 1 ))
  (( first < 1 )) && first=1

  # fc output includes real event numbers usable with !<number>
  # -l: list, -t: custom timestamp format
  fc -l -t '%Y-%m-%d %H:%M:%S' "$first" | while IFS= read -r line; do
    trimmed="${line#"${line%%[![:space:]]*}"}"

    # Parse lines that begin with an event number and timestamp.
    if [[ "$trimmed" == <->* ]]; then
      num="${trimmed%%[[:space:]]*}"
      rest="${trimmed#"$num"}"
      rest="${rest#"${rest%%[![:space:]]*}"}"
      ts="${rest[1,19]}"

      if [[ "$ts" == [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9] ]]; then
        cmd="${rest[20,-1]}"
        cmd="${cmd#"${cmd%%[![:space:]]*}"}"
        cmd="$(_histtime_decode_cmd "$cmd")"

        cmd_lines=()
        while IFS= read -r part; do
          cmd_lines+=("$(_histtime_trim_ws "$part")")
        done <<< "$cmd"

        (( ${#cmd_lines[@]} == 0 )) && cmd_lines=("")

        # Drop trailing empty lines from escaped endings.
        while (( ${#cmd_lines[@]} > 1 )) && [[ -z "${cmd_lines[-1]}" ]]; do
          cmd_lines[-1]=()
        done

        printf '%7s  %s  %s\n' "$num" "$ts" "${cmd_lines[1]}"
        for (( i = 2; i <= ${#cmd_lines[@]}; i++ )); do
          printf '%7s  %19s  %s\n' "" "" "${cmd_lines[i]}"
        done
        continue
      fi
    fi

    # Continuation line from fc itself.
    printf '%7s  %19s  %s\n' "" "" "$(_histtime_trim_ws "$line")"
  done
}

alias htime='histtime'
alias hist='histtime'
