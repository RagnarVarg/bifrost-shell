#!/usr/bin/env bash
set -euo pipefail
qs ipc -p @HOME@/.config/DankMaterialShell/shell/shell.qml call wallpaper set "$1"
