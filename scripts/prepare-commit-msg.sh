#!/usr/bin/env bash
# prepare-commit-msg hook — pre-fills a `Jira: <TICKET>` trailer from
# the branch name before the editor opens, so the ticket cross-check in
# check-commit-msg.sh (and REQUIRE_JIRA_TICKET, if a repo turns it on)
# is satisfied automatically instead of relying on the author to
# remember and retype it.
#
# EDGE CASE: only fires for a genuinely interactive commit — an empty
# message file with no $2 source. `git commit -m "..."` (source
# "message"), merges, squashes, and `--template` all skip this: the
# author or another process already decided the full message in those
# cases, and silently mutating it would be surprising.
set -euo pipefail

msg_file="$1"
source="${2:-}"

if [ -n "$source" ]; then
  exit 0
fi
if [ -s "$msg_file" ]; then
  exit 0
fi

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [[ "$branch" =~ ^(feature|bugfix|hotfix|ai)/([A-Z]+-[0-9]+)- ]]; then
  ticket="${BASH_REMATCH[2]}"
  printf '\n\nJira: %s\n' "$ticket" > "$msg_file"
fi

exit 0
