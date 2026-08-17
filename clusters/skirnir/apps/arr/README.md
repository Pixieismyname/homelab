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
- `http://flaresolverr.${DOMAIN}`

## Paths (inside containers)

Mounted paths are consistent across apps:

- Media root: `/media`
  - `/media/TV`
  - `/media/Anime`  (anime goes here)
  - `/media/Movies`
- Downloads: `/downloads`
  - `/downloads/movies`
  - `/downloads/tv`
  - `/downloads/anime`

## Host mounts

- `${DOCKER_DATA}/arr/prowlarr/config` -> `/config`
- `${DOCKER_DATA}/arr/sonarr/config` -> `/config`
- `${DOCKER_DATA}/arr/radarr/config` -> `/config`
- `${DOCKER_DATA}/arr/bazarr/config` -> `/config`
- `${DOCKER_DATA}/arr/qbittorrent/config` -> `/config`

## Ports

- qBittorrent torrent traffic: `6881/tcp` and `6881/udp`

## Environment

- All services use `${TZ}`, `${PUID}`, `${PGID}`
- qBittorrent Web UI port is set to `8080` (proxied through Caddy)

## Network

- All services join external `${PROXY_NETWORK}` network

## Notes

- qBittorrent exposes TCP/UDP 6881 for torrent traffic.
- The web UIs are routed through Caddy (no host ports for the arr apps).

## qBittorrent categories

Set category save paths in qBittorrent (`Settings` -> `Downloads` -> `Category Save Path`) to:

- `movies` -> `/downloads/movies`
- `tv` -> `/downloads/tv`
- `anime` -> `/downloads/anime`
- `audiobooks` -> `/downloads/audiobooks` (manual grabs for Audiobookshelf; no
  arr app imports these)

New downloads will be stored on the host path configured by `${DOWNLOADS_PATH}`.
