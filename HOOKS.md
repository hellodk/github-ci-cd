# Org Hooks — Versioned Multi-Tool Hook Registry & Git/AI SDLC Standard

A central, versioned registry of operational hooks for the org, split per tool
(`git/`, `helm/`, `terraform/`), each with its **own `install.sh`** and **its own
version**, plus the Git branching / AI-SDLC standard that governs how humans and
agents work.

> **Single source of truth.** This document is the spec. The `git/`, `helm/`,
> `terraform/` directories are the implementations. CI is the enforcement.

---

## Table of Contents

- [1. Philosophy: install vs enforce](#1-philosophy-install-vs-enforce)
- [2. Architecture](#2-architecture)
- [3. Repository layout](#3-repository-layout)
- [4. Versioning model](#4-versioning-model)
- [5. How hooks are wired](#5-how-hooks-are-wired)
- [6. Installing a tool set](#6-installing-a-tool-set)
  - [6.1 Git hooks (v1)](#61-git-hooks-v1)
  - [6.2 Helm hooks (v1)](#62-helm-hooks-v1)
  - [6.3 Terraform hooks (v2)](#63-terraform-hooks-v2)
- [7. Hook catalogue](#7-hook-catalogue)
- [8. Git branching strategy](#8-git-branching-strategy)
  - [8.1 Repository profiles](#81-repository-profiles)
  - [8.2 Branching model](#82-branching-model)
  - [8.3 Branch naming](#83-branch-naming)
  - [8.4 Worktrees & AI agents](#84-worktrees--ai-agents)
  - [8.5 Submodules & subtree](#85-submodules--subtree)
  - [8.6 Commit convention & release notes](#86-commit-convention--release-notes)
  - [8.7 SemVer & merge strategy](#87-semver--merge-strategy)
  - [8.8 GitOps](#88-gitops)
- [9. Enforcement hierarchy](#9-enforcement-hierarchy)
- [10. Adding a hook / bumping a version](#10-adding-a-hook--bumping-a-version)
- [11. Quick reference](#11-quick-reference)

---

## 1. Philosophy: install vs enforce

A local Git hook is **developer convenience**, not a security boundary.

`git commit --no-verify` causes Git to *skip invoking* the hook script entirely —
before it would ever run. No client-side hook can detect or prevent that. The same
is true for deleted, replaced, or never-installed hooks, and for repos cloned
without running the installer.

Therefore the model is two layers:

| Layer | Mechanism | Can be bypassed? |
|-------|-----------|------------------|
| **Install** (fast feedback) | local hooks via `install.sh` into `.git/hooks` | **yes** (`--no-verify`) |
| **Enforce** (real gate) | server-side branch protection + required status checks in CI | **no** (GitHub rejects the merge) |

Local hooks give developers and AI agents fast feedback. CI re-runs the *same*
policy server-side and is the layer that actually blocks `main`.

---

## 2. Architecture

```
                 ORGANIZATION ENGINEERING POLICY
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
   Git Policy             Repo Policy           AI SDLC Policy
       │                      │                      │
       ├─ branching           ├─ repo layout       ├─ agent branches
       ├─ commits             ├─ mono/poly         ├─ worktrees
       ├─ hooks               ├─ submodules        ├─ validation
       ├─ releases            ├─ subtree           ├─ PR creation
       ├─ semver              └─ GitOps             └─ merge restriction
       └─ merge
                              │
                              ▼
              ┌───────────────────────────────┐
              │   org-hooks registry (this repo)│
              │   git/v1   helm/v1   terraform/v2│
              └───────────────┬─────────────────┘
                              │
              ┌───────────────┼────────────────┐
              ▼               ▼                ▼
          Developer         CI/CD           AI Agents
          (install.sh)    (required checks) (install.sh)
                              │
                              ▼
                    Compliance / status check
                              │
                              ▼
                  Organization branch protection
                              │
                         ┌────┴────┐
                         ▼         ▼
                       MERGE     BLOCK
```

The registry is the policy *source*. Each tool is versioned independently so a
Terraform hook change (v2) does not force a Git hook bump (v1) and vice-versa.

---

## 3. Repository layout

```
git-branch/
├── lib/
│   └── common.sh                 # shared log/version/resolve helpers (no side effects)
├── git/
│   └── v1/                      # git hook set, version 1.x
│       ├── VERSION              # 1.0.0
│       ├── install.sh           # installs pre-commit/commit-msg/pre-push/post-commit
│       └── hooks/
│           ├── pre-commit       # forbidden files, secrets, yaml, 80-col, license
│           ├── commit-msg       # Conventional Commits + Jira + Signed-off-by
│           ├── pre-push         # build/test (skips when N/A)
│           ├── post-commit      # non-blocking notification
│           ├── pre-install      # installer phase: dependency check
│           └── post-install     # installer phase: verify + guidance
├── helm/
│   └── v1/                      # helm git-hook set, version 1.x
│       ├── VERSION              # 1.0.0
│       ├── install.sh
│       └── hooks/               # pre-commit (helm lint), commit-msg, pre-push, post-commit, pre/post-install
├── terraform/
│   └── v2/                      # terraform git-hook set, version 2.x
│       ├── VERSION              # 2.0.0
│       ├── install.sh
│       └── hooks/               # pre-commit (tf fmt/validate), commit-msg, pre-push, post-commit, pre/post-install
├── policies/
│   └── helm-lifecycle.md        # native helm.sh/hook (pre/post-install, …) reference
└── HOOKS.md                     # this document
```

**Rule:** individual hook files do **not** carry the version in their name
(`hooks/pre-commit`, never `hooks/pre-commit-v1`). The version lives once, in the
tool directory's `VERSION` file. This keeps hook references stable across patch
bumps and makes a version bump a one-line `VERSION` edit.

---

## 4. Versioning model

- Each tool directory is independently versioned with SemVer in its `VERSION` file.
- Current: `git/v1` → **1.0.0**, `helm/v1` → **1.0.0**, `terraform/v2` → **2.0.0**.
- A repository pins the version it consumes, e.g. via `.org/hooks.yaml`:

  ```yaml
  hooks:
    git: 1.0.0
    helm: 1.0.0
    terraform: 2.0.0
  ```

- Bumping the engine (hook *implementation*) is decoupled from bumping the
  *organization policy* (which checks are mandatory). A policy change does not
  require rewriting hook scripts.
- Releases are immutable tags (`git/v1.0.0`, `terraform/v2.0.0`). Never
  force-update a released version; cut a new one.

---

## 5. How hooks are wired

Local hooks are installed into the target repo's Git hooks path:

```bash
# default target = current repo root
./git/v1/install.sh
# or an explicit path
./terraform/v2/install.sh ../my-terraform-repo
```

`install.sh` resolves the destination via `git config core.hooksPath` when set,
otherwise `<repo>/.git/hooks`, then copies the four git-native hooks
(`pre-commit`, `commit-msg`, `pre-push`, `post-commit`). `pre-install` and
`post-install` are *installer phases* run by `install.sh` (dependency checks and
post-install guidance), not Git hooks.

> **Native Helm lifecycle hooks are different.** `helm.sh/hook: pre-install`,
> `post-upgrade`, etc. run as Kubernetes Jobs at `helm install/upgrade/rollback`
> time — they are chart `templates/`, not `.git/hooks`. See
> [`policies/helm-lifecycle.md`](./policies/helm-lifecycle.md). This repo's
> `helm/v1` directory provides the *Git* hooks that lint charts at commit time.

---

## 6. Installing a tool set

### 6.1 Git hooks (v1)

```bash
cd git-branch
./git/v1/install.sh            # installs into the current repo
./git/v1/install.sh /path/repo # installs into a specific repo
```

Installed checks (client-side, fast):

- **forbidden files** — `.env`, `*.pem`, `*.key`, `id_rsa`, `credentials.json`, `*.tfstate`, …
- **secret scan** — AWS keys, GitHub PATs, private-key blocks, OpenAI/Slack tokens
- **YAML validation/lint** — every staged `*.yml`/`*.yaml`
- **80-column rule** — code ≤ 80 cols; only comments may exceed, and must carry the
  Jira ID for the change (`// PLAT-1234: why this line is long`)
- **commit-msg** — Conventional Commits + Jira ID + `Signed-off-by` + ≤ 72-char subject

### 6.2 Helm hooks (v1)

```bash
./helm/v1/install.sh
```

`pre-commit` runs `helm lint` on any chart whose `Chart.yaml` changed, and
validates against `values.schema.json` when present. `commit-msg` enforces the
same contract as git/v1.

### 6.3 Terraform hooks (v2)

```bash
./terraform/v2/install.sh
```

`pre-commit` runs `terraform fmt -check` and `terraform validate` per changed
module directory. `commit-msg` enforces the same contract as git/v1.

---

## 7. Hook catalogue

| Tool | Version | Hook | What it does | Blocking? |
|------|---------|------|--------------|-----------|
| git | 1.0.0 | `pre-commit` | forbidden files, secrets, YAML, 80-col, license | yes |
| git | 1.0.0 | `commit-msg` | Conventional Commits + Jira + Signed-off-by | yes |
| git | 1.0.0 | `pre-push` | build/test when applicable | yes |
| git | 1.0.0 | `post-commit` | local notification | no |
| helm | 1.0.0 | `pre-commit` | `helm lint` on changed charts | yes |
| helm | 1.0.0 | `commit-msg` | Conventional Commits + Jira + Signed-off-by | yes |
| terraform | 2.0.0 | `pre-commit` | `terraform fmt -check` + `validate` | yes |
| terraform | 2.0.0 | `commit-msg` | Conventional Commits + Jira + Signed-off-by | yes |

The expensive checks (SAST, SCA, IaC policy, full dependency & license scan) run
**server-side** in CI, not in local hooks.

---

## 8. Git branching strategy

### 8.1 Repository profiles

Don't apply one branching model to everything. Each repo declares a profile:

| Profile | Example | Branch model | Release |
|---------|---------|--------------|---------|
| application | Go service | trunk-based | SemVer |
| library | Go module | trunk-based | SemVer |
| monorepo | many services | trunk-based | per-component SemVer |
| gitops | K8s manifests | environment branches/paths | Git SHA |
| platform | Terraform/K8s tooling | trunk-based | SemVer |
| legacy | old app | controlled GitFlow | SemVer |

A repo declares its profile in `.org/repo.yaml` so the policy engine knows which
rules apply.

### 8.2 Branching model

Default to **trunk-based** with short-lived feature branches:

```
main
 ├── feature/PLAT-1234-dg-payment-timeout
 ├── bugfix/  PLAT-1266-rk-null-pointer
 ├── hotfix/  PLAT-1277-ab-prod-crash
 ├── refactor/PLAT-1401-dg-remove-legacy
 ├── chore/   PLAT-1400-ab-upgrade-go
 └── release/ 1.8.0
```

Target branch lifetime **< 3 days** (ideally < 1 day for AI-generated changes).
Long-lived branches accumulate merge risk.

### 8.3 Branch naming

```
<type>/<JIRA-ID>-<initials>-<short-description>
```

Regex:

```
^(feature|bugfix|hotfix|chore|refactor|release)/[A-Z][A-Z0-9]+-[0-9]+-[a-z]{2,4}-[a-z0-9]+(-[a-z0-9]+)*$
```

Examples: `feature/PLAT-1234-dg-add-auth-cache`, `bugfix/PLAT-1244-rk-fix-token`.
`experiment/*` is exempt (no ticket). This makes `git blame` → branch → owner a
one-step lookup and lets `git log` cross-check that a commit's ticket matches the
branch it was made on.

### 8.4 Worktrees & AI agents

Agents must use the **same** Git primitives as humans — no `agent-main`,
`agent-bypass`, or special Git universe. An AI agent gets:

1. `git fetch --prune --tags origin`
2. `git worktree add ../worktrees/PLAT-1234-dg -b feature/PLAT-1234-dg-cache origin/main`
3. implement → run local policy → `git commit -s` → `git push` → open PR

Worktrees avoid branch-switching contention when multiple agents (or an agent +
a developer) work concurrently. The agent **never** merges to `main`.

### 8.5 Submodules & subtree

- **Submodule** — for dependencies with an independent lifecycle. The parent pins a
  specific commit; a submodule bump is a normal PR change. CI must always run
  `git submodule sync --recursive && git submodule update --init --recursive`.
- **Subtree** — when source should appear inside the consumer repo but sync from
  another repo.
- **Neither** — prefer Go modules / package managers for ordinary library deps.

A submodule update PR is validated for: allowed URL, existing commit, signed
commit, policy compliance, vulnerability status.

### 8.6 Commit convention & release notes

Conventional Commits + Jira:

```
<type>(<scope>): <JIRA-ID> <description>
```

Allowed types: `feat fix refactor perf docs test build ci chore revert`.
Example: `feat(payments): PLAT-1234 add idempotency support`.

Release notes are generated from these messages automatically:

- `feat` → **MINOR**
- `fix` → **PATCH**
- `BREAKING CHANGE:` → **MAJOR**

Developers do not hand-maintain `CHANGELOG.md` unless the profile requires it.

### 8.7 SemVer & merge strategy

`MAJOR.MINOR.PATCH` with immutable tags. Force-update of release tags is
prohibited.

Merge to `main` is **squash-only** by default (keeps history linear; the PR title
becomes the `main` commit subject, so the PR title gets its own validation in CI).
Emergency overrides use a controlled **break-glass** merge requiring
security/platform approval + reason + ticket + audit event — never a general
"force merge" capability. Force-push to `main` and to `release/*` is blocked by
branch protection.

### 8.8 GitOps

GitOps is a separate repo profile (`gitops/`). Application repos build images and
open a GitOps PR that updates the target overlay; Argo CD reconciles desired
state. CI builds; GitOps controls desired state; CD reconciles.

---

## 9. Enforcement hierarchy

```
                 POLICY
                   │
       ┌───────────┴───────────┐
       │                       │
   Developer                 CI/CD
       │                       │
   Hooks / install.sh     Required status checks
       │                       │
       └───────────┬───────────┘
                   ▼
             GitHub branch protection
                   │
             Required check + linear history + no force-push
                   │
          ┌────────┴────────┐
          ▼                 ▼
       COMPLIANT         NON-COMPLIANT
          │                 │
          ▼                 ▼
        MERGE              BLOCK
```

Because the org does not control the central GitHub server itself, the trust
boundary is the **required status check + branch protection**, not the local hook.
GitHub's org-wide rulesets support required status checks, branch/metadata
restrictions, merge-method restrictions, and force-push blocking — that is the
enforcement layer.

---

## 10. Adding a hook / bumping a version

**Add a check to an existing tool** (no version change unless behaviour changes):

1. Edit the relevant `hooks/<stage>` script under the tool's version dir.
2. Bump the patch version in `VERSION` if the check is new or changes behaviour.
3. Commit + tag (`git/v1.0.1`).

**Add a new tool or a breaking change:**

1. Create a new version directory (`terraform/v3/`) or a new tool dir (`k8s/v1/`).
2. Copy `install.sh` + `hooks/`, implement, set `VERSION`.
3. Update the consuming repos' `.org/hooks.yaml` to opt in.

Keep `lib/common.sh` the only place with logging/version/resolve logic.

---

## 11. Quick reference

```bash
# Install a tool set into the current repo
./git/v1/install.sh
./helm/v1/install.sh
./terraform/v2/install.sh

# Daily flow (human or agent)
git fetch --prune --tags origin
git switch -c feature/PLAT-1234-dg-cache origin/main
# ... edit, then:
git commit -s -m "feat(payments): PLAT-1234 add cache"
git push -u origin feature/PLAT-1234-dg-cache
# open PR → CI required checks → squash merge to main

# Bypass locally (discouraged; CI still blocks)
git commit --no-verify
```

| Must | Should | Prohibited |
|------|--------|------------|
| branch naming, commit format, Jira, hook version, secret scan, forbidden files, YAML, license, 80-col, PR validation, `main` protection, SemVer, squash merge, submodule validation, GitOps conventions | `git switch`, `git fetch --prune`, worktrees, Conventional Commits, automated release notes | force-push `main`, force-push release tags, unsigned releases, untracked submodules, disabled security checks, committing secrets, permanent policy exceptions, AI agent merge-to-`main` |
