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