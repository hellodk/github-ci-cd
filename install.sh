#!/usr/bin/env bash
# Root dispatcher for the org-hooks registry.
# Usage: ./install.sh <git|helm|terraform> [target-repo-path]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TOOL="${1:-}"
TARGET="${2:-}"

case "$TOOL" in
  git)       exec ./git/v1/install.sh "$TARGET" ;;
  helm)      exec ./helm/v1/install.sh "$TARGET" ;;
  terraform) exec ./terraform/v2/install.sh "$TARGET" ;;
  ""|-h|--help)
    echo "Usage: ./install.sh <git|helm|terraform> [target-repo-path]"
    echo "Each tool is versioned independently; see HOOKS.md."
    exit 0
    ;;
  *) echo "Unknown tool: $TOOL (expected git|helm|terraform)" >&2; exit 1 ;;
esac
