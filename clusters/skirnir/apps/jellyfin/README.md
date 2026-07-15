# jellyfin

Media server.

## URL

- `http://jellyfin.${DOMAIN}`

## Storage

- Config: `${DOCKER_DATA}/jellyfin/config`
- Cache: `${DOCKER_DATA}/jellyfin/cache`
- Transcodes: `${DOCKER_DATA}/jellyfin/transcodes` (local storage, not remote mount)
- Media: `${MEDIA_PATH}` mounted read-only at `/media`

## Environment

- Uses `${TZ}`, `${PUID}`, `${PGID}`

## Network

- Joins external `${PROXY_NETWORK}` network

## Hardware transcoding (Intel VAAPI)

Tyr has an Intel CometLake-U GT2 UHD Graphics iGPU.

The compose passes `/dev/dri` into the container and adds the host `render`
group (GID 993) so the internal process can access the GPU.

### Jellyfin Dashboard settings

After deploying, configure in **Dashboard > Playback > Transcoding**:

1. Hardware acceleration: **Video Acceleration API (VAAPI)**
2. VA-API Device: `/dev/dri/renderD128`
3. Enable hardware decoding for: H.264, HEVC, VP9, AV1 (tick all supported)
4. Enable hardware encoding
5. Enable Tone-mapping (if HDR content exists)
6. Preferred encoder: leave default or VAAPI
7. Transcoding thread count: 0 (auto)
8. Throttle transcoding: enabled

### Host prerequisites

On Tyr, ensure the Intel VA-API driver is installed:

```bash
sudo apt-get install -y intel-media-va-driver-non-free vainfo
vainfo   # should list profiles without errors
```

Verify render device:

```bash
ls -la /dev/dri/renderD128
# Should show group 'render'
```

No user/group changes needed on the host - the compose `group_add: ["993"]`
handles GPU access inside the container.

## Notes

- This stack does not expose ports on the host; access is via the reverse proxy.
- Media is on a remote SMB/NFS mount (`/mnt/media`). The mount is read-only
  inside the container to prevent accidental writes.
- Transcode temp files are stored locally (`${DOCKER_DATA}/jellyfin/transcodes`)
  to avoid thrashing the network mount.
- Resource limits are set to 6 CPUs / 6 GB RAM as a safety net; hardware
  transcoding uses negligible CPU.

## Troubleshooting playback

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Buffering on all clients | Transcoding without HW accel | Enable VAAPI in Dashboard |
| Plays fine then stutters | Transcode temp on slow mount | Verify `/config/transcodes` is local |
| Playback error on specific files | Unsupported codec / subtitle burn-in | Check Jellyfin logs; force direct play or convert file |
| Black screen, audio only | HDR tone-mapping failing | Disable tone-mapping or update VA-API driver |
| Permission denied in logs | GPU access denied | Verify `group_add` matches host render GID |
| Audio far too quiet on TV | TV downmixing 5.1/7.1 itself | See "Quiet audio" below |

## Quiet audio on TV clients (surround downmix)

Symptom: 100% volume sounds like ~20%. Cause: the Android TV client
advertises 5.1 support, so the server transcodes surround→5.1 AAC and the
TV's own decoder does a quiet downmix. The server's stereo-downmix settings
(Dashboard > Playback > Transcoding) never apply because the server is not
the one downmixing to stereo.

Fix: `ffmpeg-wrapper.sh` (mounted from this directory, activated via the
`JELLYFIN_FFMPEG` env var in compose.yaml) rewrites every audio encode to
force stereo output (rewriting `-ac 6/8` to `-ac 2`, so the TV never does
its own quiet downmix) and injects a compressor + limiter + makeup-gain
filter, bringing transcodes to YouTube-like loudness (~-15 dB mean). Plain
`loudnorm` was tried first and measured too weak (film peaks leave no
headroom for gain without compression).

Notes:

- `JELLYFIN_FFMPEG` is the ONLY way Jellyfin 10.8+ accepts a custom ffmpeg
  path — mounting a wrapper without it does nothing (a dead wrapper mounted
  that way sat in this stack until July 2026).
- The wrapper must live in `/usr/lib/jellyfin-ffmpeg/` next to the real
  binary, because Jellyfin resolves ffprobe as a sibling of the ffmpeg path.
- Verify it is active: Jellyfin startup log should say
  `MediaEncoder: FFmpeg: /usr/lib/jellyfin-ffmpeg/ffmpeg-wrapper.sh`, and
  transcode logs should show a `loudnorm` filter in the command line.
- Server downmix settings are also set sanely (algorithm NightmodeDialogue,
  boost 2) in case a stereo-only client ever does trigger a server downmix;
  the wrapper appends to any existing `-af` chain rather than replacing it.

