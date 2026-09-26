pragma Singleton
import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// One physical-brightness model for Settings, Control Center, keys and OSD.
Singleton {
    id: root
    property var displays: []
    property var pending: ({})
    property var inFlight: null
    property bool busy: false
    property bool probed: false
    property string error: ""
    property int users: 0
    readonly property bool available: displays.length > 0
    readonly property string provider: available ? displays[0].provider : ""
    readonly property real value: available ? valueFor(displays[0]) : 0
    signal changed

    function valueFor(display): real {
        return pending[display.id] !== undefined ? pending[display.id] : inFlight && inFlight.id === display.id ? inFlight.value : display.value;
    }
    function retain() { users++; refresh(); }
    function release() { users = Math.max(0, users - 1); }
    function refresh() {
        if (busy || Object.keys(pending).length) return;
        busy = true;
        Exec.run(["python3", Paths.repoDir + "/tools/brightness.py", "list"], (code, out) => {
            busy = false;
            probed = true;
            if (code === 0) {
                try { displays = JSON.parse(out).displays || []; } catch (e) {}
            }
            if (Object.keys(pending).length) applyTimer.restart();
        }, 30000, root);
    }
    function setDisplay(id: string, v: real) {
        if (!displays.some(d => d.id === id) || !isFinite(v)) return;
        pending = Object.assign({}, pending, { [id]: Math.max(0.01, Math.min(1, v)) });
        applyTimer.restart();
    }
    function set(v: real) { if (available) setDisplay(displays[0].id, v); }
    function adjust(delta: real) { if (available) set(value + delta); }
    function applyNext() {
        if (busy) return;
        const id = Object.keys(pending)[0];
        if (!id) return;
        const v = pending[id];
        inFlight = { id: id, value: v };
        const rest = Object.assign({}, pending); delete rest[id]; pending = rest;
        busy = true;
        Exec.run(["python3", Paths.repoDir + "/tools/brightness.py", "set", id, String(v)], (code, out) => {
            busy = false;
            error = code === 0 ? "" : I18n.tr("Could not change brightness");
            if (code === 0) {
                displays = displays.map(d => d.id === id ? Object.assign({}, d, { value: v }) : d);
                changed();
            }
            inFlight = null;
            if (Object.keys(pending).length) applyTimer.restart();
            else refresh();
        }, 15000, root);
    }
    Timer { id: applyTimer; interval: 150; onTriggered: root.applyNext() }
    // DDC has no push protocol. Refresh only while a consumer is visible.
    Timer { interval: 10000; repeat: true; running: root.users > 0; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
