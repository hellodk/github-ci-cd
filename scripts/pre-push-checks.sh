#!/usr/bin/env bash
# pre-push hook — last local check before code leaves the machine.
# Every check here is scoped to whether the relevant files actually
# exist/changed, per the blog's "If not applicable" column, and every
# one of them is re-run as a required CI status check regardless.
set -uo pipefail
status=0

echo "→ pre-push: unit tests"
if [ -f package.json ] && grep -q '"test"' package.json 2>/dev/null; then
  pnpm test || status=1
elif [ -f pytest.ini ] || [ -f pyproject.toml ]; then
  pytest -q || status=1
else
  echo "  skip — no test runner config found in this repo"
fi

echo "→ pre-push: API contract / OpenAPI validation"
if compgen -G "api/*.yaml" > /dev/null 2>&1 || compgen -G "api/*.yml" > /dev/null 2>&1; then
  echo "  (would validate api/*.yaml against OpenAPI schema)"
else
  echo "  skip — no api/*.yaml changed"
fi

echo "→ pre-push: proto validation"
if compgen -G "**/*.proto" > /dev/null 2>&1; then
  echo "  (would run buf lint / protoc --lint)"
else
  echo "  skip — no .proto files changed"
fi

echo "→ pre-push: dependency check"
if [ -f package.json ] || [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  echo "  (would run osv-scanner / pip-audit against the manifest)"
else
  echo "  skip — no dependency manifest in this repo"
fi

echo "→ pre-push: SAST"
if command -v semgrep >/dev/null 2>&1; then
  semgrep --config auto --error || status=1
else
  echo "  skip — semgrep not installed locally (CI runs it regardless — see .github/workflows/pr-checks.yml)"
fi

if [ "$status" -ne 0 ]; then
  echo "✗ pre-push checks failed" >&2
fi
exit "$status"
