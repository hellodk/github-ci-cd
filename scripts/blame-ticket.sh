#!/usr/bin/env bash
# `git blame`, but resolves each line straight to its ticket instead of
# just a commit SHA — the actual point of putting the ticket in the
# branch name and the commit trailer is that this lookup becomes one
# command instead of blame -> log -> read the message by hand.
#
# Usage: scripts/blame-ticket.sh <file> [start:end]
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <file> [start:end]" >&2
  exit 1
fi

file="$1"
range_args=()
if [ "$#" -ge 2 ]; then
  range_args=(-L "${2/:/,}")
fi

python3 - "$file" "${range_args[@]}" <<'PYEOF'
import subprocess, sys, re

fname = sys.argv[1]
extra_args = sys.argv[2:]

raw = subprocess.run(
    ["git", "blame", "--porcelain", *extra_args, "--", fname],
    capture_output=True, text=True, check=True
).stdout.splitlines()

ticket_re = re.compile(r'[A-Z]{2,}-[0-9]+')
commit_line_re = re.compile(r'^([0-9a-f]{40}) \d+ (\d+)')
ticket_cache = {}

i = 0
while i < len(raw):
    m = commit_line_re.match(raw[i])
    if not m:
        i += 1
        continue
    sha, new_lineno = m.group(1), int(m.group(2))
    i += 1
    content = ""
    while i < len(raw) and not raw[i].startswith('\t'):
        i += 1
    if i < len(raw):
        content = raw[i][1:]
        i += 1

    if sha not in ticket_cache:
        # All-zero SHA = uncommitted working-tree change; nothing to look up yet.
        if set(sha) == {"0"}:
            ticket_cache[sha] = "(uncommitted)"
        else:
            msg = subprocess.run(
                ["git", "log", "-1", "--format=%B", sha],
                capture_output=True, text=True, check=True
            ).stdout
            found = ticket_re.findall(msg)
            ticket_cache[sha] = found[0] if found else "—"

    print(f"{new_lineno:>5} {ticket_cache[sha]:>10}  {sha[:8]}  {content}")
PYEOF
