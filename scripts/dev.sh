#!/usr/bin/env bash
# Runs Bifrost Shell for development next to the production desktop.
#
#   scripts/dev.sh                 overlay mode (default, safe next to DMS)
#   scripts/dev.sh --preset NAME   layer a preset without changing config.json
#   scripts/dev.sh --mode MODE     overlay | nested | production
#
# Uses the real config dir (~/.config/bifrost). Stop with Ctrl+C.
# Nothing here touches ~/.config/hypr, DMS or systemd units; compositor
# effects (blur for bifrost:* layers) are runtime-only and vanish on
# `hyprctl reload` or reboot.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
mode="overlay"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) mode="$2"; shift 2 ;;
        --preset) export BIFROST_PRESET="$2"; shift 2 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ "$mode" == "production" ]] && systemctl --user -q is-active dms.service 2>/dev/null; then
    echo "DMS is running; production mode would fight it over notifications, lock and wallpaper." >&2
    echo "Use --mode overlay for development." >&2
    exit 1
fi

export BIFROST_RUN_MODE="$mode"
exec qs -n -p "$repo/shell"
