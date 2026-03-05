# jellyfin

Media server.

## URL

- `http://jellyfin.${DOMAIN}`

## Storage

- Config: `${DOCKER_DATA}/jellyfin/config`
- Cache: `${DOCKER_DATA}/jellyfin/cache`
- Media: `${MEDIA_PATH}` mounted read-only at `/media`

## Notes

- This stack does not expose ports on the host; access is via the reverse proxy.
- If you later use remote storage (Windows SMB mount), set `MEDIA_PATH=/mnt/media`
  in Mímir’s Well (on the host).
