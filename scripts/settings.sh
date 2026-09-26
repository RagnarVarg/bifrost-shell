#!/usr/bin/env bash
# Opens Bifrost Settings, or shows and focuses the running instance.
#   bifrost-settings                 first section
#   bifrost-settings glass           a section (see schema/*.json "section")
#   bifrost-settings bar.height      the section of a setting, highlighted
#
# Settings is one resident process per session: closing the window only hides
# it. This script asks the running instance to show itself and then checks
# that the window really is mapped. Only an instance that does not answer or
# cannot map its window is replaced; a healthy one is always reused.
set -uo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
entry="$repo/shell/settings.qml"
page="${1:-}"

ipc() {
    timeout 3 qs ipc -p "$entry" call settings "$@" 2>/dev/null
}

instance_pids() {
    qs list -p "$entry" -j 2>/dev/null | python3 -c '
import json, sys
try:
    for i in json.load(sys.stdin):
        print(i.get("pid", ""))
except Exception:
    pass'
}

mapped() {
    ipc status | grep -q '"mapped":true'
}

start() {
    export BIFROST_SETTINGS_PAGE="$page"
    # Same run mode as the running shell (its ping answers "pong <mode>").
    if [[ -z "${BIFROST_RUN_MODE:-}" ]]; then
        mode="$(timeout 2 qs ipc -p "$repo/shell" call bifrost ping 2>/dev/null | awk '{print $2}')"
        export BIFROST_RUN_MODE="${mode:-overlay}"
    fi
    # shellcheck source=env.sh
    source "$repo/scripts/env.sh"
    exec qs -n -d -p "$entry" >/dev/null 2>&1
}

if ipc open "$page" >/dev/null; then
    for _ in $(seq 1 20); do
        mapped && exit 0
        sleep 0.1
    done
    echo "bifrost-settings: the running instance did not map its window; restarting it" >&2
fi

# Either no instance, or one that is stuck: end only those, then start fresh.
for pid in $(instance_pids); do
    echo "bifrost-settings: replacing unresponsive instance $pid" >&2
    kill "$pid" 2>/dev/null
    for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    kill -9 "$pid" 2>/dev/null
done
start
