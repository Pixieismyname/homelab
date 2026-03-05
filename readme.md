# homelab

GitOps-managed homelab configuration.

## Hosts

- **skirnir**: Ubuntu + Docker Compose

## Workflow

- Git is the source of truth.
- The host pulls and reconciles config on a schedule using `systemd` + a deploy script.

## Layout

- `clusters/<host>/apps/*` — Docker Compose stacks (desired state)
- `clusters/<host>/bootstrap/*` — one-time bootstrap artifacts (systemd units, install notes)
- `clusters/<host>/scripts/*` — deploy + utility scripts
- `docs/*` — design notes, storage, conventions

## Quick start (skirnir)

See `clusters/skirnir/bootstrap/install.md`.

## Reconcile loop (detailed)

This repo is applied continuously on the host by a `systemd` timer + service + script chain.

### Trigger and scheduler

- `clusters/skirnir/bootstrap/systemd/skirnir-reconcile.timer`
  - Runs once shortly after boot (`OnBootSec=2min`)
  - Re-runs every 5 minutes (`OnUnitActiveSec=5min`)
  - Catches up after downtime (`Persistent=true`)

### Execution unit

- `clusters/skirnir/bootstrap/systemd/skirnir-reconcile.service`
  - Runs as `gitops`
  - Uses `REPO_DIR=/opt/homelab`, `BRANCH=main`, `REMOTE=origin`
  - Calls `clusters/skirnir/scripts/reconcile.sh`

### What reconcile.sh does

1. **Preflight checks**
   - Verifies required commands (`git`, `docker`)
   - Verifies `REPO_DIR` exists and is a valid git work tree
2. **Git sync**
   - `git fetch "$REMOTE" --prune`
   - Confirms remote branch exists
   - `git checkout -B "$BRANCH" "${REMOTE}/${BRANCH}"`
   - `git reset --hard "${REMOTE}/${BRANCH}"`
3. **Env reconciliation (safe)**
   - Requires `clusters/skirnir/.env`
   - Requires `clusters/skirnir/mimir.env.example`
   - Merges **missing keys only** from `mimir.env.example` into `.env`
   - Existing `.env` values are never overwritten
4. **Compose apply**
   - Validates each stack file exists
   - Runs `docker compose ... config -q`
   - Runs `docker compose ... pull`
   - Runs `docker compose ... up -d --remove-orphans`

### Failure behavior

- Reconcile is fail-fast: if any required check fails, the run exits with a clear error.
- Existing running containers are not torn down by a failed precheck.
- Next timer run retries automatically.

### Manual run (same path as timer)

Use this for ad-hoc verification:

```bash
cd /opt/homelab
clusters/skirnir/scripts/reconcile.sh
```
