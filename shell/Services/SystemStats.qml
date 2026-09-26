pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// CPU and memory usage from /proc. Polls only while retained:
//   Component.onCompleted: SystemStats.retain(); Component.onDestruction: SystemStats.release()
Singleton {
    id: root

    property int users: 0
    property real cpu: 0            // 0..1
    property real memTotalKb: 0
    property real memUsedKb: 0
    readonly property real mem: memTotalKb > 0 ? memUsedKb / memTotalKb : 0   // 0..1
    property real uptimeSeconds: 0
    // CPU package temperature (°C) from hwmon: k10temp (AMD), coretemp
    // (Intel) or zenpower; NaN when no sensor is found.
    property real cpuTemp: NaN
    property string cpuTempPath: ""

    property var _lastCpu: null

    function retain() {
        users++;
        if (users === 1)
            sample();
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    function sample() {
        const stat = statFile.readFresh();
        if (stat) {
            const f = stat.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            if (_lastCpu) {
                const dt = total - _lastCpu.total;
                cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - _lastCpu.idle) / dt)) : cpu;
            }
            _lastCpu = { idle: idle, total: total };
        }
        if (cpuTempPath) {
            const t = tempFile.readFresh();
            cpuTemp = t ? Number(t) / 1000 : NaN;
        }
        const up = uptimeFile.readFresh();
        if (up)
            uptimeSeconds = Number(up.split(" ")[0]) || 0;
        const info = memFile.readFresh();
        if (info) {
            const get = k => {
                const m = info.match(new RegExp("^" + k + ":\\s+(\\d+)", "m"));
                return m ? Number(m[1]) : 0;
            };
            memTotalKb = get("MemTotal");
            memUsedKb = memTotalKb - get("MemAvailable");
        }
    }

    Timer {
        interval: Config.values.systemStats ? Config.values.systemStats.intervalMs : 2000
        repeat: true
        running: root.users > 0
        onTriggered: root.sample()
    }

    WatchedFile {
        id: statFile

        path: "/proc/stat"
        watch: false
    }

    WatchedFile {
        id: tempFile

        path: root.cpuTempPath
        watch: false
    }

    Component.onCompleted: Exec.run(["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); case $n in k10temp|coretemp|zenpower) echo $d/temp1_input; exit;; esac; done"], (code, out) => root.cpuTempPath = out.trim())

    WatchedFile {
        id: uptimeFile

        path: "/proc/uptime"
        watch: false
    }

    WatchedFile {
        id: memFile

        path: "/proc/meminfo"
        watch: false
    }
}
