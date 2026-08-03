# github-ci-cd

Git Branching Strategy for AI-Assisted Development — **Integration-Gate Flow**.

A single self-contained HTML guide covering:

- **Branch Architecture** — branching strategies compared, the 8-branch model, monorepo vs. polyrepo, naming and commit conventions
- **Pipelines** — PR review, security gates, backend/web release, mobile release (Android/iOS + HeadSpin + RASP), semantic versioning & release notes, end-to-end flow
- **Hooks · Webhooks · Governance** — client/server git hooks (with bypass reporting), Helm release hooks, GitHub webhooks, AI guardrails, OpenTelemetry requirements, branch protection, and OPA/Kyverno policy

## View it

Open [`2026-08-02-ai-git-branching-strategy.html`](./2026-08-02-ai-git-branching-strategy.html) directly in a browser — no build step, no dependencies, all diagrams are inline animated SVG.

## Reference implementation

The Git Hooks section (Tab 3) isn't just documentation — this repo runs it.

### Branch naming

`<type>/<JIRA-TICKET>-<username>` — e.g. `feature/ABC-145-hellodk`, `ai/ABC-300-claude`. `experiment/*` is exempt (no ticket). This makes `git blame` → branch → owner a one-step lookup and lets `git log` cross-check that a commit's ticket matches the branch it was made on.

### Local hooks (`.pre-commit-config.yaml` + `scripts/`)

| Hook | Script | What it does |
|---|---|---|
| `pre-commit` | [`check-branch-name.sh`](./scripts/check-branch-name.sh) | Enforces the naming convention above; soft-warns (doesn't block) if the username doesn't match your GitHub login |
| `pre-commit` | [`check-ticket-traceability.sh`](./scripts/check-ticket-traceability.sh) | Non-blocking — warns when a newly added `HACK`/`WORKAROUND`/`XXX` line has no ticket ID on it |
| `prepare-commit-msg` | [`prepare-commit-msg.sh`](./scripts/prepare-commit-msg.sh) | Pre-fills a `Jira: ABC-145` trailer from the branch name before your editor opens (interactive commits only — never touches `git commit -m`) |
| `commit-msg` | [`check-commit-msg.sh`](./scripts/check-commit-msg.sh) | Conventional Commits format, blank line before body, `BREAKING CHANGE:` footer format, branch↔commit ticket cross-check, `Signed-off-by`, no forbidden words, 72-char subject limit |
| `post-commit` | [`post-commit-notify.sh`](./scripts/post-commit-notify.sh) | Non-blocking: local changelog draft, optional Slack/OTel notify |
| `pre-push` | [`pre-push-checks.sh`](./scripts/pre-push-checks.sh) | Tests, API contract validation, dependency check, SAST — each skips cleanly when not applicable |

Convenience tool (not a hook): [`scripts/blame-ticket.sh <file> [start:end]`](./scripts/blame-ticket.sh) — `git blame`, but resolves each line straight to its ticket instead of a bare SHA.

**Install:**

```bash
pip install pre-commit
pre-commit install   # wires up pre-commit, prepare-commit-msg, commit-msg, post-commit, pre-push
```

### Server-side enforcement (the part that actually can't be bypassed)

**Important correction to how this is usually described**: git gives hooks no way to block `--no-verify` — when that flag is passed, git skips invoking the hook script entirely, before it would ever run. No pre-commit/commit-msg/pre-push script can detect or prevent it. That's true of every git client, not a gap in this setup.

What actually prevents a bypass from reaching `main` is **server-side branch protection**, which this repo has live, not just documented:

```bash
gh api repos/hellodk/github-ci-cd/branches/main/protection
```

- `main` requires a PR — direct pushes (`--no-verify` or not) are rejected by GitHub, not by a hook
- 6 required status checks must pass: branch naming, every commit message, the PR title (squash-merge commits *that*, not the individual commits — see below), `pre-commit` re-run in CI, `terraform-ci`, `helm-ci`
- `enforce_admins: true` — the repo owner isn't exempt either
- Linear history (squash-only), no force-pushes, no branch deletion, conversations must be resolved

**Not yet enabled**: `required_signatures` (commit signing). Turning it on would lock out pushes from this machine — no signing key is configured here yet. Set one up, then:
```bash
gh api -X POST repos/hellodk/github-ci-cd/branches/main/protection/required_signatures
```

### Why the PR title has its own check

`main`'s branch protection requires linear (squash-only) history — so on merge, the **PR title** becomes the commit subject on `main`, not any of the branch's individual commits. `pr-checks.yml` validates the title itself (`pr-title` job) with the same Conventional Commits/ticket rules, via `SKIP_TRAILER_CHECKS=1` (no body or `Signed-off-by` expected on a title).

### Helm release hooks

[`helm/example-service/`](./helm/example-service/) is a real, `helm lint`-clean chart demonstrating all 7 native `helm.sh/hook` types (pre/post-install, pre/post-upgrade, test, pre/post-rollback, pre/post-delete) with industry-standard annotations and their edge cases — see [its README](./helm/example-service/README.md). This is a different mechanism from `helm-ci.yml` above: that lints charts at PR time, this runs Kubernetes Jobs at `helm install`/`upgrade`/`rollback`/`uninstall` time.

### Scope notes (solo reference repo, not a licensed enterprise deployment)

- JIRA-ticket enforcement in `commit-msg` beyond the branch cross-check is off by default (`REQUIRE_JIRA_TICKET=1` to turn it on) — there's no ticket tracker wired up here.
- The enterprise scanners in the Security Tooling table (SonarQube, Checkmarx, Prisma Cloud) aren't called from `pr-checks.yml` — no licensed credentials to call them with. Each is a straightforward additional job once `SONAR_TOKEN` / `CHECKMARX_*` / `PRISMA_*` secrets exist, following the same pattern as the jobs already there.
- `terraform-ci.yml` / `helm-ci.yml` have nothing to lint yet since this repo has no `terraform/` directory (it does now have `helm/`, so `helm-ci.yml` is live).
