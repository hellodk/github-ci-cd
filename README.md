# github-ci-cd

Git Branching Strategy for AI-Assisted Development — **Integration-Gate Flow**.

A single self-contained HTML guide covering:

- **Branch Architecture** — branching strategies compared, the 8-branch model, monorepo vs. polyrepo, naming and commit conventions
- **Pipelines** — PR review, security gates, backend/web release, mobile release (Android/iOS + HeadSpin + RASP), semantic versioning & release notes, end-to-end flow
- **Hooks · Webhooks · Governance** — client/server git hooks (with bypass reporting), Helm release hooks, GitHub webhooks, AI guardrails, OpenTelemetry requirements, branch protection, and OPA/Kyverno policy

## View it

Open [`2026-08-02-ai-git-branching-strategy.html`](./2026-08-02-ai-git-branching-strategy.html) directly in a browser — no build step, no dependencies, all diagrams are inline animated SVG.

## Reference implementation

The Git Hooks section (Tab 3) isn't just documentation — this repo runs it:

| Blog concept | Where it lives |
|---|---|
| `pre-commit` (formatting, secrets, branch naming) | [`.pre-commit-config.yaml`](./.pre-commit-config.yaml), [`scripts/check-branch-name.sh`](./scripts/check-branch-name.sh) |
| `commit-msg` (Conventional Commits, Signed-off-by) | [`scripts/check-commit-msg.sh`](./scripts/check-commit-msg.sh) |
| `post-commit` (non-blocking notify) | [`scripts/post-commit-notify.sh`](./scripts/post-commit-notify.sh) |
| `pre-push` (tests, contracts, SAST) | [`scripts/pre-push-checks.sh`](./scripts/pre-push-checks.sh) |
| Required-status-check twin (Tab 3's "local hooks aren't the enforcement boundary") | [`.github/workflows/pr-checks.yml`](./.github/workflows/pr-checks.yml) |
| `terraform-ci` / `helm-ci` (skip-as-success pattern) | [`.github/workflows/terraform-ci.yml`](./.github/workflows/terraform-ci.yml), [`.github/workflows/helm-ci.yml`](./.github/workflows/helm-ci.yml) |

**Install the local hooks:**

```bash
pip install pre-commit
pre-commit install   # wires up pre-commit + commit-msg + post-commit + pre-push in one go
```

**Scope notes** (this is a solo reference repo, not a licensed enterprise deployment):
- JIRA-ticket enforcement in `commit-msg` is off by default (`REQUIRE_JIRA_TICKET=1` to turn it on) — there's no ticket tracker wired up here.
- The enterprise scanners in the Security Tooling table (SonarQube, Checkmarx, Prisma Cloud) aren't called from `pr-checks.yml` — this repo has no licensed credentials for them. Each is a straightforward additional job once `SONAR_TOKEN` / `CHECKMARX_*` / `PRISMA_*` secrets exist, following the same pattern as the jobs already there.
- `terraform-ci.yml` / `helm-ci.yml` are real, working workflows — they just have nothing to lint yet since this repo has no `terraform/` or `helm/` directory. Add one and the checks activate.
