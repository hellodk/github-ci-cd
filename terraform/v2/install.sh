#!/usr/bin/env bash
# terraform/v2/install.sh — installs the org-hooks terraform v2 git-hook set.
# Usage: ./install.sh [target-repo-path]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/hooks/pre-install"

TARGET="${1:-$(repo_root)}"
HOOKS_DEST="$(resolve_hooks_dest "$TARGET")"
export HOOKS_DEST
mkdir -p "$HOOKS_DEST/lib"
cp "$SCRIPT_DIR/../../lib/common.sh" "$HOOKS_DEST/lib/common.sh"
cp "$SCRIPT_DIR/VERSION" "$HOOKS_DEST/VERSION"

for h in pre-commit commit-msg pre-push post-commit; do
  src="$SCRIPT_DIR/hooks/$h"
  [ -f "$src" ] || continue
  install -m 0755 "$src" "$HOOKS_DEST/$h"
  log_ok "installed terraform git hook: $h"
done

source "$SCRIPT_DIR/hooks/post-install"
