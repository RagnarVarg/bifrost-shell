pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import qs.Compositor
import qs.Core

// Facts for "Om Bifrost": Bifrost's own version (git), Quickshell, Qt, the
// compositor, OS, kernel, host, CPU and uptime. Read on demand (refresh()),
// not polled.
Singleton {
    id: info

    property var values: ({})
    property bool loading: false
    property real refreshedAt: 0

    readonly property string script: [
        "r=\"$1\"",
        "echo \"bifrost=$(git -C \"$r\" describe --tags --always --dirty 2>/dev/null)\"",
        "echo \"bifrostDate=$(git -C \"$r\" log -1 --format=%cs 2>/dev/null)\"",
        "echo \"quickshell=$(qs --version 2>/dev/null | head -1 | sed -E 's/^Quickshell ([^ ]+).*/\\1/')\"",
        "echo \"qt=$(for t in /usr/lib/qt6/bin/qtpaths qtpaths6 qtpaths; do $t --qt-version 2>/dev/null && break; done)\"",
        "echo \"kernel=$(uname -r)\"",
        "echo \"os=$( . /etc/os-release 2>/dev/null; echo \"${PRETTY_NAME:-$NAME}\")\"",
        "echo \"host=$(cat /proc/sys/kernel/hostname)\"",
        "echo \"cpu=$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)\"",
        "echo \"cores=$(nproc)\"",
        "echo \"uptime=$(cut -d' ' -f1 /proc/uptime)\"",
        "echo \"user=$(id -un)\""
    ].join("\n")

    function refresh() {
        if (loading)
            return;
        loading = true;
        Exec.run(["sh", "-c", script, "sh", Paths.repoDir], (code, out) => {
            const v = {};
            for (const line of out.split("\n")) {
                const i = line.indexOf("=");
                if (i > 0)
                    v[line.slice(0, i)] = line.slice(i + 1).trim();
            }
            v.cpu = (v.cpu || "").replace(/\s+\d+-Core Processor$/, "").replace(/\s+Processor$/, "").replace(/\s+CPU @.*$/, "");
            v.compositor = (Compositor.displayName || Compositor.kind) + (Compositor.version ? " " + Compositor.version : "");
            v.runMode = RunMode.mode;
            info.values = v;
            info.loading = false;
            info.refreshedAt = Date.now();
        });
    }

    function uptimeText(): string {
        const s = Number(values.uptime || 0) + (Date.now() - refreshedAt) / 1000;
        if (!(s > 0))
            return "";
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + " d " : "") + (d > 0 || h > 0 ? h + " h " : "") + m + " min";
    }
}
