#!/usr/bin/env bash
# Shared helpers for the org-hooks registry.
# Sourced by every install.sh and hook script. No side effects on import.
set -euo pipefail

log_info()  { printf '\033[0;34m[org-hooks]\033[0m %s\n' "$*" >&2; }
log_warn()  { printf '\033[0;33m[org-hooks]\033[0m %s\n' "$*" >&2; }
log_error() { printf '\033[0;31m[org-hooks]\033[0m %s\n' "$*" >&2; }
log_ok()    { printf '\033[0;32m[org-hooks]\033[0m %s\n' "$*" >&2; }

# tool_version <path-to-VERSION-file> -> prints trimmed first line
tool_version() {
  local f="$1"
  if [ -f "$f" ]; then
    head -n1 "$f" | tr -d '[:space:]'
  else
    echo "0.0.0"
  fi
}

# require_bin <name> -> exit 1 with message if missing
require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "required binary not found: $1"
    return 1
  fi
}

# repo_root -> toplevel of the target git repo, else current dir
repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# resolve_hooks_dest <root> -> absolute path where hooks should be installed
resolve_hooks_dest() {
  local root="$1"
  local dest="$root/.git/hooks"
  # honour core.hooksPath when set
  local hp
  hp="$(git -C "$root" config core.hooksPath 2>/dev/null || true)"
  if [ -n "$hp" ]; then
    case "$hp" in
      /*) dest="$hp" ;;
      *)  dest="$root/$hp" ;;
    esac
  fi
  printf '%s' "$dest"
}
