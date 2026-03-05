# proxy (Caddy)

Reverse proxy for homelab services.

## Purpose

Routes hostnames under `${DOMAIN}` to containers on the shared `${PROXY_NETWORK}` Docker network.

Active hostnames include:

- `${DNS_HOST}`
- `${HOMEPAGE_HOST}`
- `${PORTAINER_HOST}`
- `${JELLYFIN_HOST}`
- `${PAPERLESS_HOST}`
- `${HOMEASSISTANT_HOST}`
- `${PROWLARR_HOST}`
- `${SONARR_HOST}`
- `${RADARR_HOST}`
- `${BAZARR_HOST}`
- `${QBITTORRENT_HOST}`

Planned (when stack exists):

- `${WAZUH_HOST}`

## Ports

- 80/tcp exposed on host (LAN HTTP)

## Storage

- `${DOCKER_DATA}/proxy/caddyfile` -> `/etc/caddy/Caddyfile` (read-only)
- `${DOCKER_DATA}/proxy/data` -> `/data`
- `${DOCKER_DATA}/proxy/config` -> `/config`

## Notes

- Uses `host.docker.internal:host-gateway` mapping for host-network service proxying
  (for Home Assistant).
- All target services must:
  1) join the external Docker network `${PROXY_NETWORK}`
  2) have stable container names matching the `Caddyfile` upstreams
