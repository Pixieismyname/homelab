# audiobookshelf

Audiobook and podcast server — the audiobook counterpart to Jellyfin.

Handles series/author/narrator metadata, per-user progress sync, sleep timer
and playback speed, with native iOS/Android apps.

## URL

- `http://audiobooks.${DOMAIN}`

## Paths (inside container)

- `/audiobooks` — audiobook library root
- `/podcasts` — podcast library root
- `/config` — database and settings
- `/metadata` — covers, cached metadata, backups

## Host mounts

- `${DOCKER_DATA}/audiobookshelf/config` -> `/config`
- `${DOCKER_DATA}/audiobookshelf/metadata` -> `/metadata`
- `${MEDIA_PATH}/Audiobooks` -> `/audiobooks`
- `${MEDIA_PATH}/Podcasts` -> `/podcasts`

## Ports

- None on the host. The container listens on `80`, proxied by Caddy.

## Network

- Joins external `${PROXY_NETWORK}` network

## Environment

- Uses `${TZ}`, `${PUID}`, `${PGID}` from shared `.env`

## First-time setup

1. Open `http://audiobooks.${DOMAIN}` and create the root account (the first
   account created becomes admin — there is no default password).
2. Add a library, type **Books**, folder `/audiobooks`.
3. Optionally add a second library, type **Podcasts**, folder `/podcasts`.

Recommended library layout, which the scanner reads without extra tagging:

```
/audiobooks/<Author>/<Series>/<Book Title>/<files>
/audiobooks/<Author>/<Book Title>/<files>
```

## Getting books in

There is no Sonarr/Radarr equivalent for audiobooks any more — Readarr was
retired and archived by the Servarr team — so imports are manual by default:

1. In Prowlarr, enable the book/audiobook indexers and search from there.
2. Send the grab to qBittorrent under the `audiobooks` category, which saves to
   `${DOWNLOADS_PATH}/audiobooks`.
3. Move the finished folder into `${MEDIA_PATH}/Audiobooks/<Author>/...`, then
   hit **Scan** on the library (or wait for the scheduled scan).

If you would rather not move files, uncomment the `/downloads` mount in
`compose.yaml` and add it as a second, read-only library.

Optional add-ons, if manual grabbing gets tedious:

- **AudiobookRequest** — Jellyseerr-style request UI that searches through the
  existing Prowlarr and pushes to qBittorrent.
- **beets + beets-audible** — tags from Audible and lays files out in exactly
  the structure above.
- **auto-m4b** — merges multi-file MP3 rips into single chaptered `.m4b` files.

## Notes

- The image runs as root upstream, so `compose.yaml` pins
  `user: "${PUID}:${PGID}"`. `scripts/reconcile.sh` creates and chowns
  `/config`, `/metadata` and both library roots to that user; without it the
  container crash-loops on a read-only config dir.
- Podcasts are downloaded by Audiobookshelf itself (RSS), not through the arr
  stack — no indexer or download client needed for those.
- Backups are written to `/metadata/backups` on a schedule set in the UI.
- `${MEDIA_PATH}` is not mounted whole: only the two library roots are exposed,
  and read-write, since the scanner writes covers and can rename files.
