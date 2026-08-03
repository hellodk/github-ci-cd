#!/usr/bin/env bash
# commit-msg hook — validates against the Conventional Commits table in
# the blog's "Branch Naming & Commit Convention" section (Tab 1), plus
# the extra structure release-please/semantic-release actually need to
# parse the message correctly for changelog generation.
#
# JIRA-ticket enforcement is OFF by default: this repo has no ticket
# tracker wired up. Set REQUIRE_JIRA_TICKET=1 to turn it on in a repo
# that does. The branch↔commit ticket cross-check below is separate
# and always on — it only fires when the branch name carries a ticket
# per the new <type>/<JIRA-TICKET>-<username> convention.
#
# Env vars:
#   PR_BRANCH=<name>       use this instead of `git symbolic-ref` for
#                          the branch↔ticket cross-check — required in
#                          CI, where actions/checkout leaves you on a
#                          detached HEAD and symbolic-ref returns empty
#   SKIP_TRAILER_CHECKS=1  skip the blank-line and Signed-off-by checks
#                          — for validating a PR *title* (single line,
#                          no body/trailer expected) rather than a
#                          real commit message
set -euo pipefail

msg_file="$1"
subject="$(head -n1 "$msg_file")"

fail() { echo "✗ $1" >&2; exit 1; }

# 1. Conventional Commits format (types from the blog's commit table,
#    plus the custom otel:/ai:/security: types). `!` after the type or
#    scope marks a breaking change per the spec.
types='feat|fix|perf|security|refactor|docs|build|ci|test|otel|ai'
if ! [[ "$subject" =~ ^(${types})(\([a-z0-9_.-]+\))?!?:\ .+ ]]; then
  fail "Commit subject doesn't match Conventional Commits format.
  Expected: <type>(<scope>): <description>   e.g. feat(auth): add OAuth login
  Allowed types: ${types//|/, }"
fi

# 2. Blank line between subject and body. release-please/semantic-release
#    (and `git log --format=%B`) split on the first blank line to find
#    where the subject ends — a body glued directly to line 1 gets
#    mangled or silently dropped from the generated changelog.
if [ "${SKIP_TRAILER_CHECKS:-0}" != "1" ]; then
  line_count="$(wc -l < "$msg_file")"
  if [ "$line_count" -gt 1 ]; then
    second_line="$(sed -n '2p' "$msg_file")"
    if [ -n "$second_line" ]; then
      fail "Line 2 must be blank — separate the subject from the body with an empty line."
    fi
  fi
fi

# 3. BREAKING CHANGE footer, if present, must match exactly —
#    release-please matches this string case-sensitively with a single
#    colon+space. "Breaking change:" or "BREAKING-CHANGE:" won't be
#    recognized and the major-version bump silently won't happen.
if grep -qi '^breaking[ -]change' "$msg_file"; then
  if ! grep -qE '^BREAKING CHANGE: .+' "$msg_file"; then
    fail "Found a breaking-change marker that isn't exactly 'BREAKING CHANGE: <description>' (case-sensitive) — release-please won't recognize anything else."
  fi
fi

# 4. JIRA ticket ID present anywhere (opt-in — see header comment).
if [ "${REQUIRE_JIRA_TICKET:-0}" = "1" ]; then
  if ! grep -qE '[A-Z]{2,}-[0-9]+' "$msg_file"; then
    fail "No JIRA ticket ID found (expected pattern like ABC-123)."
  fi
fi

# 5. Branch↔commit ticket cross-check. Catches the copy-paste mistake
#    of committing ABC-999 in the message while sitting on the
#    ABC-145-<user> branch. Only fires when the branch actually
#    carries a ticket (feature/bugfix/hotfix/ai — not main/release/
#    integration/experiment).
branch="${PR_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null || true)}"
if [[ "$branch" =~ ^(feature|bugfix|hotfix|ai)/([A-Z]+-[0-9]+)- ]]; then
  branch_ticket="${BASH_REMATCH[2]}"
  if ! grep -q "$branch_ticket" "$msg_file"; then
    fail "Commit message doesn't mention $branch_ticket — the ticket from branch '$branch'. Add it to the subject or body."
  fi
fi

# 6. Signed-off-by trailer present (git commit -s, or added by hand).
if [ "${SKIP_TRAILER_CHECKS:-0}" != "1" ]; then
  if ! grep -qE '^Signed-off-by: .+ <.+@.+>$' "$msg_file"; then
    fail "Missing 'Signed-off-by' trailer — commit with 'git commit -s'."
  fi
fi

# 7. No forbidden words.
forbidden='wip|fixup!|squash!|temp commit|do not merge'
if grep -qiE "$forbidden" <<<"$subject"; then
  fail "Subject line contains a forbidden marker (${forbidden//|/, }) — commits with these markers must be squashed/finished before landing."
fi

# 8. Length limit — 72 chars is the conventional git subject-line cap.
if [ "${#subject}" -gt 72 ]; then
  fail "Subject line is ${#subject} chars, max is 72."
fi
if [ -z "${subject// }" ]; then
  fail "Commit message is empty."
fi

exit 0
