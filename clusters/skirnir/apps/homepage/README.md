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

## Docker integration

Homepage mounts the Docker socket read-only to display container status/widgets.
