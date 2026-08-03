#!/usr/bin/env bash
# post-commit hook — non-blocking side effects only. Per the blog:
# "the commit object already exists locally, so this hook is for side
# effects, never gates." This script NEVER exits non-zero.

log_file="$(git rev-parse --git-dir 2>/dev/null)/hooks.log"
sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
subject="$(git log -1 --pretty=%s 2>/dev/null || echo "")"
author="$(git log -1 --pretty=%an 2>/dev/null || echo "")"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "[$timestamp] $sha by $author: $subject"
} >> "$log_file" 2>/dev/null || true

# Draft changelog entry, appended locally (never committed automatically —
# a human reviews and folds this into CHANGELOG.md, or the release-please
# Release PR supersedes it entirely).
draft_file="$(git rev-parse --show-toplevel 2>/dev/null)/.changelog-draft.local"
if [ -n "${draft_file:-}" ]; then
  echo "- $subject ($sha)" >> "$draft_file" 2>/dev/null || true
fi

# Optional Slack/webhook notification — only fires if configured.
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  curl -fsS -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"Commit $sha by $author: $subject\"}" \
    "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
fi

# Optional OTel heartbeat — see Tab 3's "Catching --no-verify
# proactively" callout. Only fires if a collector endpoint is set.
if [ -n "${OTEL_COLLECTOR_URL:-}" ]; then
  curl -fsS -X POST -H 'Content-type: application/json' \
    --data "{\"hook\":\"post-commit\",\"sha\":\"$sha\"}" \
    "$OTEL_COLLECTOR_URL" >/dev/null 2>&1 || true
fi

exit 0
