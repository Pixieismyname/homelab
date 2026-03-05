# skirnir

Ubuntu host running homelab services via Docker Compose.

## Data paths on host

Conventions (bind mounts):

- `/srv/docker/<stack>/...` — container configs/state
- `/srv/<purpose>/...` — shared data (media, paperless, etc.)

## Apps

Stacks live in `apps/`:

- `proxy/` (Caddy reverse proxy)
- `dns/` (AdGuard Home)
- `homeassistant/`
- `jellyfin/`
- `arr/`
- `paperless/`
- `wazuh/` (planned)

## GitOps deploy

The reconcile entrypoint is `scripts/reconcile.sh`.

## Environment

Mímir’s Well lives at `mimir.env.example`.

Runtime values are read from `clusters/skirnir/.env`.

Reconcile auto-merges missing keys from `mimir.env.example` into `.env` without
overwriting existing values.
