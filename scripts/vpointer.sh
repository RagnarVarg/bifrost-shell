#!/usr/bin/env bash
# Dev aid: builds tools/dev/vpointer (a wlr virtual pointer) into
# ~/.cache/bifrost/dev and runs it with the given size; commands on stdin
# (see tools/dev/vpointer.c). Point WAYLAND_DISPLAY at a nested Hyprland:
# the pointer is real, so running it against the session moves your cursor.
#   WAYLAND_DISPLAY=wayland-2 scripts/vpointer.sh 1720 1000 <<< $'glide 800 10 400\nsleep 600'
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo/tools/dev"
out="${XDG_CACHE_HOME:-$HOME/.cache}/bifrost/dev"
bin="$out/vpointer"
if [[ ! -x "$bin" || "$src/vpointer.c" -nt "$bin" ]]; then
    mkdir -p "$out"
    wayland-scanner client-header "$src/wlr-virtual-pointer-unstable-v1.xml" "$out/wlr-virtual-pointer-unstable-v1-client-protocol.h"
    wayland-scanner private-code "$src/wlr-virtual-pointer-unstable-v1.xml" "$out/wlr-virtual-pointer-unstable-v1-protocol.c"
    cc -O1 -I"$out" -o "$bin" "$src/vpointer.c" "$out/wlr-virtual-pointer-unstable-v1-protocol.c" -lwayland-client -lm
fi
exec "$bin" "$@"
