#!/usr/bin/env bash
# Dev aid: the login screen in a nested Hyprland (a window on your desktop),
# talking to tools/dev/fakegreetd.py instead of greetd. Nothing is installed,
# nobody is logged in, power buttons only report (BIFROST_GREETER_DRYRUN=1).
# Goes through bin/bifrost-greeter (of BIFROST_GREETER_ROOT: the repo, or an
# installed copy), so the fallback runs too
# (it prints FALLBACK instead of starting dms-greeter).
#   scripts/greeter-test.sh <scratch dir> [fakegreetd args, default: --user $USER:test]
# In <scratch>: cache/ (fill with BIFROST_GREETER_CACHE=<scratch>/cache bifrostctl greeter sync),
# run/, fakegreetd.log, greeter.out. Drive it with
#   WAYLAND_DISPLAY=<nested> qs ipc -p $PWD/shell/greeter.qml call greeter status|login|selectSession|power …
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="${1:?scratch dir}"; shift || true
mkdir -p "$scratch/cache/state" "$scratch/run"
[[ $# -gt 0 ]] || set -- --user "$USER:test"
python3 "$repo/tools/dev/fakegreetd.py" "$scratch/greetd.sock" "$@" > "$scratch/fakegreetd.log" 2>&1 &
fake=$!
trap 'kill $fake 2>/dev/null' EXIT
cat > "$scratch/extra.lua" <<'LUA'
hl.monitor({ output = "", mode = "1720x1000", position = "0x0", scale = 1 })
LUA
root="${BIFROST_GREETER_ROOT:-$repo}"
launcher="$root/bin/bifrost-greeter"; [[ -x "$launcher" ]] || launcher="$root/greeter/bin/bifrost-greeter"
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -S "$scratch/greetd.sock" ]] && break; sleep 0.2; done
GREETD_SOCK="$scratch/greetd.sock" \
BIFROST_GREETER_ROOT="${BIFROST_GREETER_ROOT:-$repo}" \
BIFROST_GREETER_CACHE="$scratch/cache" \
BIFROST_GREETER_RUN="$scratch/run" \
BIFROST_GREETER_DRYRUN=1 \
BIFROST_GREETER_HYPR_EXTRA="$scratch/extra.lua" \
BIFROST_GREETER_SESSIONS="${BIFROST_GREETER_SESSIONS:-/usr/share/wayland-sessions}" \
BIFROST_GREETER_FALLBACK="echo FALLBACK" \
    "$launcher" > "$scratch/greeter.out" 2>&1
echo "bifrost-greeter exited $?"
