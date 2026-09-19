// Standalone snap-preview overlay. Deliberately a separate Quickshell
// instance from the main DMS shell (qs -p .../snap-preview), so nothing here
// can ever affect the topbar/dock. Controlled by ~/.config/hypr/config/
// edge-snap.lua writing "hide" or "monitor,x,y,w,h" to a small state file
// (not via `qs ipc call`: this Quickshell version's IPC CLI rejects any
// call with arguments, verified empirically - zero-arg calls work, any
// call with 1+ positional args fails with "argument not expected"
// regardless of quoting/typing/delimiter).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property string activeMonitor: ""
    property real rectX: 0
    property real rectY: 0
    property real rectW: 0
    property real rectH: 0

    property color accentColor: "#7daea3"
    property color surfaceColor: "#282828"

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.cache/DankMaterialShell/dms-colors.json"
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyColors(text())
    }

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/dms-snap-preview.state"
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyState(text())
        onLoadFailed: root.activeMonitor = ""
    }

    function applyState(text) {
        const line = text.trim();
        if (!line || line === "hide") {
            root.activeMonitor = "";
            return;
        }
        const parts = line.split(",");
        if (parts.length !== 5)
            return;
        root.activeMonitor = parts[0];
        root.rectX = parseFloat(parts[1]);
        root.rectY = parseFloat(parts[2]);
        root.rectW = parseFloat(parts[3]);
        root.rectH = parseFloat(parts[4]);
    }

    function applyColors(text) {
        try {
            const data = JSON.parse(text);
            const mode = data.mode === "light" ? "light" : "dark";
            const c = data.colors?.[mode];
            if (c?.primary)
                root.accentColor = c.primary;
            if (c?.surface_container_high)
                root.surfaceColor = c.surface_container_high;
        } catch (e) {
            // keep previous/default colors
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData

            screen: modelData
            visible: root.activeMonitor === modelData.name
            color: "transparent"

            WlrLayershell.namespace: "dms:snap-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            mask: Region {
                item: noInput
            }
            Item {
                id: noInput
                width: 0
                height: 0
            }

            Rectangle {
                x: root.rectX
                y: root.rectY
                width: root.rectW
                height: root.rectH
                radius: 16
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4)
                border.width: 3
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.95)
                visible: root.activeMonitor === modelData.name && root.rectW > 0 && root.rectH > 0

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
