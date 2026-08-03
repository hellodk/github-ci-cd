#!/usr/bin/env bash
# commit-msg hook — validates against the Conventional Commits table in
# the blog's "Branch Naming & Commit Convention" section (Tab 1).
#
# JIRA-ticket enforcement is OFF by default: this repo has no ticket
# tracker wired up. Set REQUIRE_JIRA_TICKET=1 to turn it on in a repo
# that does (matches the blog's documented default for those repos).
set -euo pipefail

msg_file="$1"
subject="$(head -n1 "$msg_file")"
body="$(cat "$msg_file")"

fail() { echo "✗ $1" >&2; exit 1; }

# 1. Conventional Commits format (types from the blog's commit table,
#    plus the custom otel:/ai:/security: types).
types='feat|fix|perf|security|refactor|docs|build|ci|test|otel|ai'
if ! [[ "$subject" =~ ^(${types})(\([a-z0-9_.-]+\))?!?:\ .+ ]]; then
  fail "Commit subject doesn't match Conventional Commits format.
  Expected: <type>(<scope>): <description>   e.g. feat(auth): add OAuth login
  Allowed types: ${types//|/, }"
fi

# 2. JIRA ticket ID present in the subject or body (opt-in).
if [ "${REQUIRE_JIRA_TICKET:-0}" = "1" ]; then
  if ! grep -qE '[A-Z]{2,}-[0-9]+' "$msg_file"; then
    fail "No JIRA ticket ID found (expected pattern like ABC-123)."
  fi
fi

# 3. Signed-off-by trailer present (git commit -s, or added by hand).
if ! grep -qE '^Signed-off-by: .+ <.+@.+>$' "$msg_file"; then
  fail "Missing 'Signed-off-by' trailer — commit with 'git commit -s'."
fi

# 4. No forbidden words.
forbidden='wip|fixup!|squash!|temp commit|do not merge'
if grep -qiE "$forbidden" <<<"$subject"; then
  fail "Subject line contains a forbidden marker (${forbidden//|/, }) — commits with these markers must be squashed/finished before landing."
fi

# 5. Length limit — 72 chars is the conventional git subject-line cap.
if [ "${#subject}" -gt 72 ]; then
  fail "Subject line is ${#subject} chars, max is 72."
fi
if [ -z "${subject// }" ]; then
  fail "Commit message is empty."
fi

exit 0
