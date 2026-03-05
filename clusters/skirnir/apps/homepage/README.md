# homepage

Dashboard / launcher for homelab services.

## URL

- `http://home.${DOMAIN}`

## Config

All Homepage configuration is stored in Git:

- `config/settings.yaml`
- `config/services.yaml`
- `config/widgets.yaml`
- `config/docker.yaml`

These files are mounted read-only into the container at `/app/config`.

## Network

- Joins external `${PROXY_NETWORK}` network

## Docker integration

Homepage mounts the Docker socket read-only to display container status/widgets.
