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
- `home-assistant/`
- `jellyfin/`
- `arr/`
- `paperless/`
- `wazuh/`

## GitOps deploy
The reconcile entrypoint is `scripts/deploy.sh`.

## Environment
Mímir’s Well lives at `mimir.env.example`.
During deployment it is copied to `.env` so Compose can load variables.