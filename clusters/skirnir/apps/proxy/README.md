# proxy (Caddy)

Reverse proxy for homelab services.

## Purpose
Routes hostnames under `${DOMAIN}` to containers on the shared `${PROXY_NETWORK}` Docker network.

Planned hostnames:
- `${JELLYFIN_HOST}`
- `${PAPERLESS_HOST}`
- `${HOMEASSISTANT_HOST}`
- `${WAZUH_HOST}`

## Ports
- 80/tcp exposed on host (LAN HTTP)

## Notes
- All target services must:
  1) join the external Docker network `${PROXY_NETWORK}`
  2) have stable container names matching the `Caddyfile` upstreams