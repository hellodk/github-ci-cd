#!/usr/bin/env bash
# Enforces the branch naming convention documented in the blog's
# "Branch Naming & Commit Convention" table (Tab 1).
#
# main / integration / release/vX.Y are protected server-side (branch
# protection + CODEOWNERS) — their names aren't a developer choice, so
# this check only applies to the branch types people actually create:
# feature/*, bugfix/*, hotfix/*, ai/*, experiment/*.
set -euo pipefail

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

# Detached HEAD (e.g. CI checkout, rebase) — nothing to validate.
if [ -z "$branch" ]; then
  exit 0
fi

protected_re='^(main|integration|release/v[0-9]+\.[0-9]+)$'
allowed_re='^(feature|bugfix|hotfix)/[A-Z]+-[0-9]+-[a-z0-9-]+$|^ai/[a-z0-9-]+$|^experiment/[a-z0-9-]+$'

if [[ "$branch" =~ $protected_re ]]; then
  exit 0
fi

if [[ "$branch" =~ $allowed_re ]]; then
  exit 0
fi

cat >&2 <<EOF
✗ Branch name '$branch' doesn't match the naming convention.

Allowed patterns:
  feature/JIRA-desc     e.g. feature/ABC-145-login
  bugfix/JIRA-desc       e.g. bugfix/ABC-240-payment
  hotfix/JIRA-desc       e.g. hotfix/ABC-520-search
  ai/description         e.g. ai/refactor-cache
  experiment/topic       e.g. experiment/new-ui

Rename with: git branch -m <new-name>
EOF
exit 1
