#!/usr/bin/env bash
# Runs inside the greeter's Hyprland (greeter/hyprland.lua): the login screen,
# then ends that Hyprland. Its exit code is kept for bifrost-greeter, which
# falls back to dms-greeter when the login screen ends without a login.
# After a crash Quickshell's own handler ends this process (the fallback then
# takes over); should a restarted instance keep crashing here, the second
# crash ends it too, so there is never an endless restart.
root="${BIFROST_GREETER_ROOT:-/usr/share/bifrost-greeter}"
run="${BIFROST_GREETER_RUN:?}"
log="$run/greeter.log"
qs -n -p "$root/shell/greeter.qml" > "$log" 2>&1 &
pid=$!
code=""
while kill -0 "$pid" 2>/dev/null; do
    if [[ "$(grep -c 'Quickshell has crashed' "$log" 2>/dev/null)" -ge 2 ]]; then
        kill "$pid" 2>/dev/null
        code=crashloop
        break
    fi
    sleep 1
done
wait "$pid"
status=$?
echo "${code:-$status}" > "$run/greeter.exit"
hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
