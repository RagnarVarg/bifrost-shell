#!/usr/bin/env bash
# Runs the Core selftest (shell/selftest.qml) and the bifrostctl tests in
# isolated config dirs.
# Never touches ~/.config/bifrost. Exit code 0 = all passed.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d -t bifrost-selftest.XXXXXX)"
log="$tmp/selftest.log"
trap 'rm -rf "$tmp"' EXIT

# Overlay explicitly: a terminal started from the session inherits production.
BIFROST_RUN_MODE=overlay BIFROST_LANG=en BIFROST_CONFIG_DIR="$tmp/config" qs -p "$repo/shell/selftest.qml" >"$log" 2>&1 &
pid=$!

for _ in $(seq 1 400); do
    grep -q "SELFTEST DONE" "$log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
done
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true

out="$(sed -E 's/\x1b\[[0-9;]*m//g' "$log")"

if grep -q "ERROR" <<<"$out"; then
    echo "QML errors:"
    grep "ERROR" <<<"$out" || true
fi
results="$(grep -oE "(PASS|FAIL) .*" <<<"$out" || true)"
if [[ "${1:-}" == "-v" ]]; then
    echo "$results"
else
    grep "^FAIL" <<<"$results" || true
fi

summary="$(grep -o "SELFTEST DONE.*" <<<"$out" || true)"
if [[ -z "$summary" ]]; then
    echo "selftest did not finish; log:"
    tail -30 <<<"$out"
    exit 2
fi
echo "$summary"
[[ "$summary" == *"fail=0" ]] || exit 1

# unittest reports on stderr; the CLI's own prints go to stdout.
if ctl="$(python3 "$repo/tools/test_bifrostctl.py" 2>&1 >/dev/null)"; then
    echo "BIFROSTCTL TESTS $(tail -3 <<<"$ctl" | head -1)"
else
    echo "$ctl"
    exit 1
fi

# Real backend against a delayed Hyprland IPC server (no session changes).
python3 "$repo/tools/test_hyprland_startup.py"

python3 "$repo/tools/test_dependencies.py"
