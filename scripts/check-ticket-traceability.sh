#!/usr/bin/env bash
# Non-blocking pre-commit check — warns (never fails the commit) when a
# newly added line has a "why is this weird" marker (HACK/WORKAROUND/
# XXX) with no ticket ID on the same line.
#
# This is deliberately narrow: requiring a ticket comment on every
# changed line would be impractical and would just get ignored. The
# branch name and commit trailer already give `git blame` a ticket for
# free on every line (see check-branch-name.sh / prepare-commit-msg.sh)
# — this check exists only for the lines where THAT isn't enough,
# because the line itself needs a standalone explanation for the next
# reader who's just skimming the file, not running git blame.
set -uo pipefail

marker_re='HACK|WORKAROUND|XXX'
ticket_re='[A-Z]{2,}-[0-9]+'
found=0
file=""
lineno=0

while IFS= read -r line; do
  case "$line" in
    "diff --git a/"*)
      file="${line#diff --git a/}"
      file="${file%% b/*}"
      ;;
    "@@ "*)
      newstart="$(echo "$line" | sed -E 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+).*/\2/')"
      lineno=$((newstart - 1))
      ;;
    "+++"*) : ;;
    "+"*)
      lineno=$((lineno + 1))
      content="${line#+}"
      if echo "$content" | grep -qEi "$marker_re" && ! echo "$content" | grep -qE "$ticket_re"; then
        marker="$(echo "$content" | grep -oEi "$marker_re" | head -1)"
        echo "⚠ $file:$lineno has a $marker marker with no ticket reference on the same line" >&2
        found=1
      fi
      ;;
  esac
done < <(git diff --cached --unified=0 -- . ':!*.md')

if [ "$found" -eq 1 ]; then
  echo "  → non-blocking. Add the ticket inline, e.g. '# ABC-123: why this is here'." >&2
fi

exit 0
