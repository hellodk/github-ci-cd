#!/usr/bin/env bash
# Enforces the branch naming convention documented in the blog's
# "Branch Naming & Commit Convention" table (Tab 1):
#   <type>/<JIRA-TICKET>-<username>
#
# The username suffix is what makes `git blame` → branch → owner a
# one-step lookup without needing to cross-reference a PR. It also
# means two people never collide on the same branch name for the same
# ticket (ABC-145-hellodk vs ABC-145-someoneelse can coexist).
#
# main / integration / release/vX.Y are protected server-side (branch
# protection + CODEOWNERS) — their names aren't a developer choice, so
# this check only applies to the branch types people actually create.
# experiment/* is deliberately exempt from the ticket requirement —
# it's exploratory, "no guarantees" work that often predates a ticket.
set -euo pipefail

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

# Detached HEAD (e.g. CI checkout, rebase) — nothing to validate.
if [ -z "$branch" ]; then
  exit 0
fi

protected_re='^(main|integration|release/v[0-9]+\.[0-9]+)$'
ticket_re='^(feature|bugfix|hotfix|ai)/([A-Z]+-[0-9]+)-([a-z0-9][a-z0-9._-]*)$'
experiment_re='^experiment/[a-z0-9-]+$'

if [[ "$branch" =~ $protected_re ]]; then
  exit 0
fi

if [[ "$branch" =~ $experiment_re ]]; then
  exit 0
fi

if [[ "$branch" =~ $ticket_re ]]; then
  branch_user="${BASH_REMATCH[3]}"
  # Soft identity check — warns, doesn't block. Hard-blocking here would
  # false-positive on a lead cutting a branch on someone's behalf. The
  # GitHub username (not the git commit email) is the source of truth,
  # since that's what the convention is actually keying on — fall back
  # to the git email local-part when `gh` isn't authenticated (e.g. some
  # CI runners, contributors without the CLI installed).
  identity=""
  if command -v gh >/dev/null 2>&1; then
    identity="$(gh api user --jq .login 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  fi
  if [ -z "$identity" ]; then
    identity="$(git config user.email 2>/dev/null | cut -d@ -f1 | tr '[:upper:]' '[:lower:]')"
  fi
  if [ -n "$identity" ] && [ "$branch_user" != "$identity" ]; then
    echo "⚠ Branch owner '$branch_user' doesn't match your identity ('$identity') — fine if you're branching on someone else's behalf, otherwise check for a typo." >&2
  fi
  exit 0
fi

cat >&2 <<EOF
✗ Branch name '$branch' doesn't match the naming convention.

Required: <type>/<JIRA-TICKET>-<username>
  feature/ABC-145-hellodk
  bugfix/ABC-240-hellodk
  hotfix/ABC-520-hellodk
  ai/ABC-300-agent

Exempt (no ticket required — exploratory work):
  experiment/topic       e.g. experiment/new-ui

Rename with: git branch -m <new-name>
EOF
exit 1
