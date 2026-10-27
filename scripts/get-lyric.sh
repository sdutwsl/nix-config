#!/usr/bin/env bash

lrc_dir="$HOME/.cache/lrc"
current_cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-current-lyric"

mkdir -p "$lrc_dir"

player="spotify"

urlencode() {
    jq -nr --arg v "$1" '$v|@uri'
}

ad_active=false
saved_volume=""

while true; do
    trackid="$(playerctl --player="$player" metadata mpris:trackid 2>/dev/null || true)"
    is_ad=false
    if [[ "$trackid" == */com/spotify/ad/* ]]; then
        is_ad=true
    fi

    if $is_ad && ! $ad_active; then
        ad_active=true
        saved_volume="$(playerctl --player="$player" volume 2>/dev/null || true)"
        playerctl --player="$player" volume 0 2>/dev/null || true
    elif ! $is_ad && $ad_active; then
        ad_active=false
        if [ -n "$saved_volume" ]; then
            playerctl --player="$player" volume "$saved_volume" 2>/dev/null || true
            saved_volume=""
        fi
    fi

    if $is_ad; then
        printf '\n' > "$current_cache" 2>/dev/null || true
        printf '\n'
        sleep 0.5
        continue
    fi

    title="$(playerctl --player="$player" metadata title 2>/dev/null || true)"
    album="$(playerctl --player="$player" metadata album 2>/dev/null || true)"
    artist="$(playerctl --player="$player" metadata artist 2>/dev/null || true)"

    if [ -z "$title" ]; then
        printf '\n' > "$current_cache" 2>/dev/null || true
        printf '\n'
        sleep 1
        continue
    fi

    key="$(
        printf '%s\0%s\0%s' "$artist" "$album" "$title" \
        | sha256sum \
        | awk '{print $1}'
    )"

    cache_file_path="$lrc_dir/$key.lrc"

    if [ ! -s "$cache_file_path" ]; then
        url="http://127.0.0.1:28883/api/v1/lyrics/single?title=$(urlencode "$title")&album=$(urlencode "$album")&artist=$(urlencode "$artist")"

        curl -fsS "$url" \
        -o "$cache_file_path" \
        -H "Authorization: ${LRC_API_TOKEN:-114514}" \
        2>/dev/null || true
    fi

    position="$(playerctl --player="$player" position 2>/dev/null || echo 0)"

    lyrics_line="$(
        awk -v position="$position" '
      /^\[[0-9]+:[0-9.]+\]/ {
        split($0, a, "]")
        time = a[1]
        lyric = a[2]

        gsub("\\[", "", time)
        split(time, t, ":")

        total_seconds = t[1] * 60 + t[2]

        if (total_seconds <= position) {
          last_lyric = lyric
        }
      }

      END {
        print last_lyric
      }
        ' "$cache_file_path" 2>/dev/null || true
    )"

    printf '%s\n' "$lyrics_line" > "$current_cache" 2>/dev/null || true
    printf '%s\n' "$lyrics_line"

    sleep 0.2
done
