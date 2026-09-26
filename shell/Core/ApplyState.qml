pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import "ConfigLogic.js" as L

// Tracks settings whose new value is saved but not yet in effect because
// their schema `apply` mode is "reload" or "restart".
//
// The shell publishes what it applied to $XDG_RUNTIME_DIR/bifrost/applied.json
// on every (re)load; Settings runs in another process and compares against it.
Singleton {
    id: root

    property var applied: null      // { pid, startedAt, reloadedAt, restart: values, reload: values }
    // The shell that wrote applied.json is still running (checked periodically;
    // the file itself survives the process until logout).
    property bool shellRunning: false
    property var pendingReload: []
    property var pendingRestart: []
    readonly property bool needsReload: pendingReload.length > 0
    readonly property bool needsRestart: pendingRestart.length > 0

    // "applied" | "reload" | "restart"
    function status(key: string): string {
        if (pendingRestart.indexOf(key) >= 0)
            return "restart";
        if (pendingReload.indexOf(key) >= 0)
            return "reload";
        return "applied";
    }

    // Shell side: `processValues` are the values the process started with
    // (kept across Quickshell reloads), the current values are what this
    // reload applied.
    function publish(startedAt: real, processValues: var) {
        applied = {
            pid: Platform.processId,
            startedAt: startedAt,
            reloadedAt: Date.now(),
            restart: processValues,
            reload: L.clone(Config.values)
        };
        file.write(JSON.stringify(applied));
    }

    function recompute() {
        const reload = [];
        const restart = [];
        if (applied && Config.ready) {
            for (const key of Schema.keys) {
                const mode = Schema.entries[key].apply;
                if (mode === "live")
                    continue;
                const snapshot = mode === "restart" ? applied.restart : applied.reload;
                if (!L.equals(L.deepGet(snapshot, key), Config.get(key)))
                    (mode === "restart" ? restart : reload).push(key);
            }
        }
        pendingReload = reload;
        pendingRestart = restart;
    }

    function checkAlive() {
        if (!applied || !applied.pid) {
            shellRunning = false;
            return;
        }
        if (applied.pid === Platform.processId) {
            shellRunning = true;
            return;
        }
        Exec.run(["kill", "-0", String(applied.pid)], code => root.shellRunning = code === 0);
    }

    onAppliedChanged: {
        recompute();
        checkAlive();
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.applied !== null
        onTriggered: root.checkAlive()
    }

    Connections {
        target: Config

        function onRevisionChanged() {
            root.recompute();
        }
    }

    WatchedFile {
        id: file

        path: Paths.appliedFile
        onContentChanged: (content, exists) => {
            try {
                root.applied = exists ? JSON.parse(content) : null;
            } catch (e) {
                root.applied = null;
            }
        }
    }
}
