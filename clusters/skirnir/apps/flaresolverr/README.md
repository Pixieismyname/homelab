# flaresolverr

FlareSolverr service for bypassing anti-bot pages used by some indexers.

## URL

- `http://flaresolverr.${DOMAIN}`

## Network

- Joins external `${PROXY_NETWORK}` network

## Environment

- Uses `${TZ}` from shared `.env`
- `LOG_LEVEL=info`
- `LOG_HTML=false`
- `CAPTCHA_SOLVER=none`

## Notes

- No host ports are exposed.
- Access is routed through Caddy.
- Typical integration: configure Prowlarr (or other clients) to use
  `http://flaresolverr.${DOMAIN}`.
