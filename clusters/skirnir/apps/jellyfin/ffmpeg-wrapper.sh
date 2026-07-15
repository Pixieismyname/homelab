#!/bin/bash
# Jellyfin invokes this instead of ffmpeg (JELLYFIN_FFMPEG in compose.yaml).
#
# Injects a compress-then-boost filter into every audio *encode* so quiet
# theatrical surround mixes come out at YouTube-like loudness no matter what
# the client does with the channels afterwards. The TV client advertises 5.1
# support, so the server never does its own stereo downmix — the TV downmixes
# internally and the result is far too quiet without this.
#
# Plain loudnorm was measured too weak here (+4.5dB on quiet scenes): film
# audio peaks near full scale, so without crushing dynamics first there is no
# headroom for gain. Measured on real content: quiet scenes -30dB -> -17.7dB
# mean, loud scenes -25dB -> -15.2dB mean, peaks limited at -0.4dB.
#
# Non-audio calls (probing, -version, stream copy) pass through untouched.

REAL=/usr/lib/jellyfin-ffmpeg/ffmpeg
FILTER="acompressor=threshold=-30dB:ratio=8:attack=5:release=250:makeup=18dB,alimiter=level_in=1:limit=0.95:level=false"

args=("$@")

# Only rewrite commands that actually encode audio (not copy / no audio)
encodes_audio=false
has_af=false
target_layout=""
ac_idx=""
for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[$i]}" in
        -codec:a*|-c:a*|-acodec)
            if [[ "${args[$((i + 1))]}" != "copy" ]]; then
                encodes_audio=true
            fi
            ;;
        -af)
            has_af=true
            ;;
        -ac)
            ac_idx=$i
            ;;
    esac
done

# Force multichannel transcodes down to stereo: the TV's own 5.1->stereo
# downmix attenuates heavily and happens after anything we can control.
# Doing the downmix here lets the limiter use the full scale.
# Also: -ac applies at the encoder, AFTER -af filters, so the layout
# conversion must happen at the head of our own chain.
if [[ -n "$ac_idx" ]]; then
    case "${args[$((ac_idx + 1))]}" in
        1) target_layout="mono" ;;
        2) target_layout="stereo" ;;
        *)
            args[$((ac_idx + 1))]=2
            target_layout="stereo"
            ;;
    esac
fi

if [[ -n "$target_layout" ]]; then
    FILTER="aformat=channel_layouts=${target_layout},${FILTER}"
fi

if ! $encodes_audio; then
    exec "$REAL" "${args[@]}"
fi

new_args=()
for ((i = 0; i < ${#args[@]}; i++)); do
    # If Jellyfin already built an audio filter chain (e.g. a stereo
    # downmix pan), append to it instead of clobbering it.
    if [[ "${args[$i]}" == "-af" ]]; then
        new_args+=("-af" "${args[$((i + 1))]},${FILTER}")
        i=$((i + 1))
        continue
    fi
    new_args+=("${args[$i]}")
done

if ! $has_af; then
    # No existing audio filter: add ours just before the output (last arg)
    last=$((${#new_args[@]} - 1))
    out="${new_args[$last]}"
    unset "new_args[$last]"
    new_args+=("-af" "$FILTER" "$out")
fi

exec "$REAL" "${new_args[@]}"
