pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// GPU usage/temperature. NVIDIA via nvidia-smi (the only vendor-specific
// code for GPUs lives here); `available` is false when no source works.
// One probe decides availability; after that, while retained, a single
// `nvidia-smi -lms` streams a sample per interval (starting nvidia-smi for
// every sample cost ~20 ms CPU each).
Singleton {
    id: root

    property int users: 0
    property bool available: false
    property bool probed: false
    property string name: ""
    property real usage: 0          // 0..1
    property real temperature: 0    // °C
    property real memUsedMb: 0
    property real memTotalMb: 0

    readonly property int intervalMs: Math.max(2000, Config.values.systemStats ? Config.values.systemStats.intervalMs : 2000)
    readonly property var query: ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
    // Briefly off so a changed interval restarts the stream.
    property bool restarting: false

    function retain() {
        users++;
        if (users === 1 && !probed)
            probe();
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    function probe() {
        Exec.runOptional(query, (code, out) => {
            probed = true;
            parse(code === 0 ? out.split("\n")[0] : "");
        }, 3000);
    }

    function parse(line: string) {
        const f = line.split(",").map(s => s.trim());
        available = f.length >= 5 && !isNaN(Number(f[1]));
        if (!available)
            return;
        name = f[0];
        usage = Number(f[1]) / 100;
        temperature = Number(f[2]);
        memUsedMb = Number(f[3]);
        memTotalMb = Number(f[4]);
    }

    onIntervalMsChanged: {
        restarting = true;
        Qt.callLater(() => root.restarting = false);
    }

    LineWatcher {
        active: root.users > 0 && root.available && !root.restarting
        command: root.query.concat(["-lms", String(root.intervalMs)])
        onLine: text => {
            if (text.trim() !== "")
                root.parse(text);
        }
    }
}
