#!/usr/bin/env bash

CONFIG="$1/config.json"

wallpaper_path="$HOME/$(jq -r '.wallpaper_path' "$CONFIG")"
cache_path="$HOME/$(jq -r '.cache_path' "$CONFIG")"
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

mkdir -p "$cache_path"

find "$wallpaper_path" -maxdepth 1 -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" \
\) | while read -r img; do

    filename=$(basename "$img")
    out="$cache_path/$filename"

    if [[ -f "$out" && "$out" -nt "$img" ]]; then
        continue
    fi

    convert "$img" -thumbnail x500 -strip -quality 85 "$out" &

    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi

done

wait
