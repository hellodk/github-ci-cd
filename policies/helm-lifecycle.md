# Native Helm Lifecycle Hooks (reference)

This document clarifies the **different** mechanism from the Git hooks installed
by `helm/v1/install.sh`.

`helm.sh/hook` annotations turn a Kubernetes resource in a chart's `templates/`
into a **job that runs at release lifecycle moments** — not at Git commit time.
They run inside the cluster when you `helm install` / `upgrade` / `rollback` /
`uninstall`.

## Hook types

| Annotation value | When it runs |
|------------------|--------------|
| `pre-install` | after templates rendered, before any resource created |
| `post-install` | after all resources created |
| `pre-upgrade` | before an upgrade |
| `post-upgrade` | after an upgrade |
| `pre-rollback` | before a rollback |
| `post-rollback` | after a rollback |
| `pre-delete` | before deletion |
| `post-delete` | after deletion |
| `post-start` / `pre-stop` | around `helm` stop/start |

## Standard annotations

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}-migrate"
  annotations:
    "helm.sh/hook": pre-upgrade,pre-install
    "helm.sh/hook-weight": "-5"          # lower runs first
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Chart.AppVersion }}"
          command: ["/bin/sh", "-c", "migrate up"]
```

- **`helm.sh/hook-weight`** — integer; more negative runs earlier within the same
  event. Hooks of the same weight run in name order.
- **`helm.sh/hook-delete-policy`** — `before-hook-create`, `hook-succeeded`,
  `hook-failed`. Without it, hook resources persist and can block re-runs.
- A hook that fails makes the `helm` command fail (unless `hook-failed` delete
  policy is set and you tolerate it).

## Edge cases

- Hooks are **not** rendered as normal release resources — they don't show up in
  `helm list` after completion if deleted per policy.
- `pre-install`/`post-install` jobs need a `ServiceAccount`/RBAC when they talk to
  the cluster; the chart must define it.
- `post-delete` hooks cannot easily read `ConfigMap`s deleted by the same release —
  capture what you need inside the hook container before deletion.

## Relationship to `helm/v1` Git hooks

`helm/v1/install.sh` installs **Git** hooks (`pre-commit` lints charts, etc.) into
the developer/agent repo. The native lifecycle hooks above live in the chart and
run at deploy time. Both exist; they enforce at different stages.
