# paperless

Paperless-ngx (docs/archive) with PostgreSQL + Redis.

## URL

- `http://paperless.${DOMAIN}`

## Environment

This stack uses:

- Shared variables from **Mímir's Well**: `clusters/skirnir/mimir.env.example`
  - Includes DB vars (`PAPERLESS_DBNAME`, `PAPERLESS_DBUSER`, `PAPERLESS_DBPASS`)
- Stack-specific variables from: `paperless.env` (copy from `paperless.env.example`)
  - App-specific vars (for example `PAPERLESS_SECRET_KEY`)

## Storage

Host paths (from Mímir’s Well):

- `${PAPERLESS_PATH}/consume`  -> /usr/src/paperless/consume
- `${PAPERLESS_PATH}/data`     -> /usr/src/paperless/data
- `${PAPERLESS_PATH}/media`    -> /usr/src/paperless/media
- `${PAPERLESS_PATH}/export`   -> /usr/src/paperless/export

Database/redis state:

- `${DOCKER_DATA}/paperless/db`
- `${DOCKER_DATA}/paperless/redis`

## Notes

- Redis is required for Paperless background tasks/scheduler.
- No host ports are exposed; access is routed through Caddy.
