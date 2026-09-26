#!/usr/bin/env bash
# Opens the Bifrost component gallery over the current desktop.
# Close with Esc, the "Stäng" button, Ctrl+C here, or:
#   qs kill -p <repo>/shell/gallery.qml
# Runs next to DMS without touching it; the tuning panel edits
# ~/.config/bifrost/config.json.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
export BIFROST_RUN_MODE="${BIFROST_RUN_MODE:-overlay}"
exec qs -n -p "$repo/shell/gallery.qml"
