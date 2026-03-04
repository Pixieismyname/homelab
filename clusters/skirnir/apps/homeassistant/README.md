# homeassistant

Home Assistant core in Docker.

## Networking
This stack uses `network_mode: host` to improve device discovery (mDNS/SSDP),
which is often important for Google Home / Chromecast / LAN integrations.

- Home Assistant listens on: `http://<skirnir-ip>:8123`
- Caddy routes `http://ha.${DOMAIN}` to `host.docker.internal:8123`

If `host.docker.internal` is not available on the Docker host, update the proxy to use
the host LAN IP instead (we'll do this during server bring-up).

## Data
Config is stored at:

- `${DOCKER_DATA}/homeassistant/config` (bind mount on host)