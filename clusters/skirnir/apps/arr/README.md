# arr

Automation stack:

- Prowlarr (indexers)
- Sonarr (TV + Anime)
- Radarr (movies)
- Bazarr (subtitles)
- qBittorrent (downloader)

## URLs

- `http://prowlarr.${DOMAIN}`
- `http://sonarr.${DOMAIN}`
- `http://radarr.${DOMAIN}`
- `http://bazarr.${DOMAIN}`
- `http://qbittorrent.${DOMAIN}`

## Paths (inside containers)

Mounted paths are consistent across apps:

- Media root: `/media`
  - `/media/TV`
  - `/media/Anime`  (anime goes here)
  - `/media/Movies`
- Downloads: `/downloads`

## Notes

- qBittorrent exposes TCP/UDP 6881 for torrent traffic.
- The web UIs are routed through Caddy (no host ports for the arr apps).
