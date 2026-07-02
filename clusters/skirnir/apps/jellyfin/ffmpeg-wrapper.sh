#!/bin/bash
# Wrapper that inserts a volume boost audio filter into Jellyfin's ffmpeg calls.
# Jellyfin builds complex -filter_complex and -vf chains; we only inject -af for audio.
# This adds +12dB gain to compensate for quiet surround-to-AAC transcoding.

args=("$@")
new_args=()
i=0
while [ $i -lt ${#args[@]} ]; do
    new_args+=("${args[$i]}")
    # After the audio bitrate flag (-ab), inject volume filter
    if [[ "${args[$i]}" == "-ab" ]]; then
        new_args+=("${args[$((i+1))]}")
        new_args+=("-af" "volume=10dB,acompressor=threshold=-20dB:ratio=4:attack=5:release=50")
        i=$((i+1))
    fi
    i=$((i+1))
done

exec /usr/lib/jellyfin-ffmpeg/ffmpeg.bin "${new_args[@]}"
