#!/usr/bin/env zsh

# Wrap govc to source password from macOS Keychain at runtime.
# Non-secret GOVC_* vars (URL/USERNAME/INSECURE/etc.) can live in ~/.zshenv.
govc() {
  local pass govc_bin service
  govc_bin="$(brew --prefix)/bin/govc"

  if [[ ! -x "$govc_bin" ]]; then
    echo "ERROR: govc binary not found at $govc_bin" >&2
    echo "Fix: brew install govc" >&2
    return 127
  fi

  if [[ -z "${GOVC_URL:-}" ]]; then
    echo "ERROR: GOVC_URL is not set" >&2
    echo "Fix: export GOVC_URL=\"https://esxi.home\" in ~/.zshenv" >&2
    return 1
  fi

  if [[ -z "${GOVC_USERNAME:-}" ]]; then
    echo "ERROR: GOVC_USERNAME is not set" >&2
    echo "Fix: export GOVC_USERNAME=\"root\" in ~/.zshenv" >&2
    return 1
  fi

  service="${GOVC_URL#https://}"
  service="${service#http://}"
  service="${service%%/*}"

  pass="$(security find-internet-password -a "$GOVC_USERNAME" -s "$service" -w 2>/dev/null)"
  if [[ -z "$pass" ]]; then
    echo "ERROR: Keychain password not found for account '$GOVC_USERNAME' and service '$service'" >&2
    echo "Fix: security add-internet-password -a \"$GOVC_USERNAME\" -s \"$service\" -w" >&2
    return 1
  fi

  GOVC_PASSWORD="$pass" "$govc_bin" "$@"
}
