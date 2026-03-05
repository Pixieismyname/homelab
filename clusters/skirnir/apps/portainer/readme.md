# portainer

Docker web UI for **observability / inspection** on Skirnir.

## URL

- `http://portainer.${DOMAIN}`

## Intended usage

Portainer is used for:

- viewing container status
- viewing logs
- inspecting volumes/networks
- occasional exec for troubleshooting

**Source of truth remains Git.**
Do not routinely edit or deploy stacks from Portainer.

## Data

- `${DOCKER_DATA}/portainer/data` (bind mount on host)

## Security note

Portainer has powerful access to the Docker socket. Treat access as admin-level.
When deployed, create a limited day-to-day user if you want, and keep admin for emergencies.
