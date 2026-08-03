# example-service — Helm Release Hooks Reference

A working chart demonstrating every native `helm.sh/hook` type, with
industry-standard annotations and the edge cases each one has in
production. Companion to Tab 2's "Helm Release Hooks" card in the blog.

## Hooks in this chart

| Hook type | File | Weight | Delete policy | What it does |
|---|---|---|---|---|
| `pre-install`, `pre-upgrade` | `hooks/db-migration.yaml` | `-5` | `before-hook-creation,hook-succeeded` | DB schema migration — failure aborts the release, nothing new is applied |
| `post-install`, `post-upgrade` | `hooks/smoke-test.yaml` | `1` | `before-hook-creation,hook-succeeded` | HTTP smoke test against the just-deployed Service |
| `test` | `hooks/test-connection.yaml` | — | `before-hook-creation,hook-succeeded` | On-demand `helm test` check — never runs automatically |
| `pre-rollback`, `post-rollback` | `hooks/rollback.yaml` | — | `before-hook-creation,hook-succeeded` | Snapshot before, verify after — fires on manual rollback and on `--atomic`'s automatic rollback |
| `pre-delete`, `post-delete` | `hooks/delete.yaml` | — | see below | Backup before teardown, external cleanup after |

## Try it

```bash
helm lint .
helm template demo .                          # render everything
helm template demo . --show-only templates/hooks/db-migration.yaml
helm install demo . --dry-run --debug          # simulate a real install
helm install demo .
helm test demo                                 # only this triggers the `test` hook
helm upgrade demo . --atomic --timeout 5m       # auto-rollback on any hook failure
helm rollback demo 1
helm uninstall demo                            # pre-delete / post-delete fire here
```

## Edge cases (the part the annotations alone don't tell you)

1. **Pre-hook failure is clean; post-hook failure isn't.** A `pre-install`/`pre-upgrade` failure stops Helm before it touches any release resources. A `post-install`/`post-upgrade` failure happens *after* the Deployment/Service are already live — Helm marks the release `failed`, but what's running keeps running. Run `helm upgrade --atomic` so a failed post-hook triggers an automatic rollback instead of leaving a half-verified release in the cluster.

2. **`test` never runs on its own.** Not on install, not on upgrade, not even with `--wait`. It only runs on an explicit `helm test <release>` — make that command a real step in the release pipeline (see the `Integration` stage in Tab 2's Backend Release Pipeline) or it silently never executes.

3. **Delete policy is deliberately not `hook-failed`.** `before-hook-creation,hook-succeeded` cleans up on success and safely clears any leftover Job right before the next attempt — but leaves a *failed* Job in place so `kubectl logs job/...` still works for the postmortem. Adding `hook-failed` would delete the evidence the moment it's most useful.

4. **Hooks that fire on every attempt must be idempotent.** `pre-install`/`pre-upgrade` run on every single install and upgrade, not once ever. The migration tool (and the migrations themselves) must be safe to re-run — `golang-migrate`-style tools track applied versions so re-running `up` against an already-current schema is a no-op.

5. **Same-type hooks run in weight order, and a failure stops the rest.** If two hooks share `pre-upgrade`, the lower `hook-weight` runs first; if it fails, the second one never runs. Order dependencies (schema before seed data, etc.) by weight, don't assume declaration order in the templates.

6. **`restartPolicy: Never` is required**, not a style choice — Helm doesn't manage hook retries via the pod, the Job's `backoffLimit` does. `Always`/`OnFailure` here silently break the failure signal Helm relies on.

7. **Bound the Job, don't just trust `helm --timeout`.** `--timeout` only bounds how long *Helm* waits; it doesn't stop the Job from continuing to retry inside the cluster after Helm has already given up and reported failure. `backoffLimit` + `activeDeadlineSeconds` on the Job itself are the real bound.

8. **`helm uninstall --no-hooks` skips pre-delete/post-delete entirely.** That flag exists for genuine emergencies. Any use of it on a release with a backup hook should be treated as an incident, not routine.

9. **Hook Jobs should get their own ServiceAccount**, narrower than the app's — this chart reuses one for simplicity (see the comment in `serviceaccount.yaml`), but a migration Job typically needs a DB credential the running app doesn't, and vice versa.

10. **`post-delete` has no "next attempt" to clean it up.** Every other hook's `before-hook-creation` policy relies on a future install/upgrade to sweep a failed Job — `post-delete` is the last thing that runs for a release, so a failed one needs a manual `kubectl delete job` sweep; there's no automatic second chance.

11. **`crd-install` is Helm 2 legacy.** If you see it in older docs: Helm 3+ uses the chart's `crds/` directory instead — `crd-install` as a hook type no longer does anything.
