import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Motion
import qs.Modules

// Minimize and restore, drawn by Bifrost: a live picture of the window
// (WindowCapture) moves down into the dock's edge and back up. Registered as
// Compositor.windowTransitions, so every way to minimize or restore (dock,
// menus, overview, shortcuts, gestures, IPC) looks the same; the backend hides
// and shows the window without the compositor's own animation meanwhile
// (capabilities.minimizeTransition), so nothing animates twice.
// The window's place on screen is remembered at minimize, to return there;
// without it (after a shell restart) the picture grows from the middle.
Scope {
    id: root

    // Running transitions: { key, id, screen, restore, from, to, done }
    property var running: []
    // Window id -> monitor-local rect it had when minimized.
    property var places: ({})
    property int serial: 0
    readonly property int coverMs: 150      // longest wait for the first captured frame

    Component.onCompleted: Compositor.windowTransitions = root
    Component.onDestruction: if (Compositor.windowTransitions === root)
        Compositor.windowTransitions = null

    function monitorOf(w) {
        return Compositor.monitors.find(m => m.name === w.monitor) || Compositor.focusedMonitor || Compositor.monitors[0] || null;
    }

    // Monitor-local rect of a window; a fullscreen one covers its monitor.
    function rectOf(w, mon) {
        if (w.fullscreen || !(w.width > 0))
            return { x: 0, y: 0, width: mon.width, height: mon.height };
        return { x: w.x - mon.x, y: w.y - mon.y, width: w.width, height: w.height };
    }

    // Where the picture goes: small, at the middle of the dock's edge on that
    // monitor (the bottom without a dock there).
    function dockPoint(mon, rect) {
        const host = Placement.dockHosts.find(h => h.screenName === mon.name);
        const edge = host ? host.edge : "bottom";
        const w = Math.max(Theme.space.xxxl, rect.width * 0.08), h = Math.max(Theme.space.xl, rect.height * 0.08);
        const cx = edge === "left" ? 0 : edge === "right" ? mon.width : mon.width / 2;
        const cy = edge === "top" ? 0 : edge === "bottom" ? mon.height : mon.height / 2;
        return { x: cx - w / 2, y: cy - h / 2, width: w, height: h };
    }

    function start(w, restore, done) {
        const mon = monitorOf(w);
        if (!mon) {
            done();
            return;
        }
        let rect = restore ? places[w.id] : rectOf(w, mon);
        if (!rect)
            rect = { x: mon.width * 0.2, y: mon.height * 0.15, width: mon.width * 0.6, height: mon.height * 0.7 };
        if (!restore) {
            const p = Object.assign({}, places);
            p[w.id] = rect;
            places = p;
        }
        const point = dockPoint(mon, rect);
        running = running.concat([{ key: "t" + (++serial), id: w.id, screen: mon.name, restore: restore, from: restore ? point : rect, to: restore ? rect : point, done: done }]);
    }

    function finish(key) {
        running = running.filter(t => t.key !== key);
    }

    function minimize(w, hide) {
        start(w, false, hide);
    }

    function restore(w, show) {
        start(w, true, show);
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: layer

            required property var modelData
            readonly property var mine: root.running.filter(t => t.screen === modelData.name)

            screen: modelData
            visible: mine.length > 0
            color: "transparent"
            WlrLayershell.namespace: RunMode.layerNamespace("transition")
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}

            Repeater {
                model: layer.mine

                delegate: Item {
                    id: shot

                    required property var modelData
                    readonly property var t: modelData
                    readonly property string curve: t.restore ? "decelerate" : "accelerate"
                    property bool started: false
                    property bool released: false

                    x: t.from.x
                    y: t.from.y
                    width: t.from.width
                    height: t.from.height
                    opacity: t.restore ? 0 : 1
                    clip: true

                    // Minimize: the picture covers the window, then the window
                    // goes and the picture moves down. Restore: the picture
                    // moves up, then the window appears under it.
                    function begin() {
                        if (started)
                            return;
                        started = true;
                        if (!t.restore)
                            release();
                        move.start();
                    }

                    function release() {
                        if (released)
                            return;
                        released = true;
                        t.done();
                    }

                    ParallelAnimation {
                        id: move

                        BNumberAnimation { target: shot; property: "x"; to: shot.t.to.x; speed: "slow"; curve: shot.curve }
                        BNumberAnimation { target: shot; property: "y"; to: shot.t.to.y; speed: "slow"; curve: shot.curve }
                        BNumberAnimation { target: shot; property: "width"; to: shot.t.to.width; speed: "slow"; curve: shot.curve }
                        BNumberAnimation { target: shot; property: "height"; to: shot.t.to.height; speed: "slow"; curve: shot.curve }
                        BNumberAnimation { target: shot; property: "opacity"; to: shot.t.restore ? 1 : 0; speed: "slow"; curve: shot.curve }

                        onFinished: {
                            shot.release();
                            hold.start();
                        }
                    }

                    // A restored window shows up under its picture a moment
                    // after release (the compositor call); only then it goes.
                    Timer {
                        id: hold

                        interval: shot.t.restore ? 150 : 0
                        onTriggered: root.finish(shot.t.key)
                    }

                    WindowCapture {
                        anchors.fill: parent
                        source: Compositor.captureSource(shot.t.id)
                        live: true
                        onHasContentChanged: if (hasContent)
                            shot.begin()
                    }

                    // No first frame in time (or no capture): go on anyway.
                    Timer {
                        running: true
                        interval: root.coverMs
                        onTriggered: shot.begin()
                    }
                }
            }
        }
    }
}
