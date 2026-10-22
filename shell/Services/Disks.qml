pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Local file systems and how full they are (df). Read on retain and every
// 30 s while retained:
//   Disks.retain() when shown, Disks.release() when hidden.
// A device mounted in several places (Btrfs subvolumes) is listed once, at
// its shortest mount point.
Singleton {
    id: root

    property int users: 0
    // [{ device, mount, type, size, used, avail }] in bytes, the root first.
    property var disks: []
    property bool loaded: false

    function retain() {
        users++;
        if (users === 1)
            refresh();
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    function refresh() {
        Exec.run(["df", "-l", "-B1", "--output=source,fstype,size,used,avail,target",
                  "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"], (code, out) => {
            root.disks = root.parse(out);
            root.loaded = true;
        }, 5000);
    }

    function parse(out: string): var {
        const byDevice = {};
        for (const line of out.split("\n").slice(1)) {
            // The mount point is last and may contain spaces.
            const m = line.match(/^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
            if (!m || Number(m[3]) === 0)
                continue;
            const d = { device: m[1], type: m[2], size: Number(m[3]), used: Number(m[4]), avail: Number(m[5]), mount: m[6] };
            const seen = byDevice[d.device];
            if (!seen || d.mount.length < seen.mount.length)
                byDevice[d.device] = d;
        }
        return Object.values(byDevice).sort((a, b) => a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount));
    }

    function bytes(n: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < units.length - 1) {
            n /= 1000;
            i++;
        }
        return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + units[i];
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.users > 0
        onTriggered: root.refresh()
    }
}
