# homeassistant

Home Assistant core in Docker.

## Networking

This stack uses `network_mode: host` to improve device discovery (mDNS/SSDP),
which is often important for Google Home / Chromecast / LAN integrations.

- Home Assistant listens on: `http://<skirnir-ip>:8123`
- Caddy routes `http://ha.${DOMAIN}` to `host.docker.internal:8123`

The proxy stack maps `host.docker.internal` to Docker host-gateway, so the route
is stable on Linux hosts.

## Data

Config is stored at:

- `${DOCKER_DATA}/homeassistant/config` (bind mount on host)
