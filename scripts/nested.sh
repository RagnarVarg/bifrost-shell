#!/usr/bin/env bash
# Starts a nested Hyprland (a window on the current desktop) running Bifrost in
# "nested" mode with its own D-Bus session. Used to test what overlay mode
# can't: notifications server, session lock, polkit, keybinds and window
# actions. Uses hypr/nested.lua only; the real Hyprland config is untouched.
#
# Keys inside use SUPER+ALT+SHIFT (the host keeps plain SUPER combos):
#   +T terminal, +Space launcher, +N notifications, +L lock, +X power menu,
#   +1..5 workspaces, +Q close window, +E quit; SUPER+CTRL+ALT+1..5 moves a window.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
export BIFROST_REPO="$repo"
exec dbus-run-session -- Hyprland --config "$repo/hypr/nested.lua"
