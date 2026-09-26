import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compat
import qs.Core
import qs.Components.Motion
import qs.Services

// Wallpaper on the background layer of every screen, with a cross-fade. The
// image and how it fills come from Services/Wallpapers (shared with the
// workspace preview).
// Only when the run mode owns the wallpaper (nested/production); in overlay
// mode the production shell draws it.
Scope {
    id: wallpaper

    readonly property var cfg: Config.values.wallpaper

    Variants {
        model: RunMode.ownsWallpaper ? Quickshell.screens : []

        delegate: PanelWindow {
            id: window

            required property var modelData

            property string shown: ""
            property bool flip: false

            screen: modelData
            color: Theme.palette.void
            WlrLayershell.namespace: RunMode.layerNamespace("wallpaper")
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            readonly property int fill: Wallpapers.fillMode
            readonly property string source: Wallpapers.sourceFor(modelData.name)

            component Layer: Image {
                anchors.fill: parent
                fillMode: window.fill
                asynchronous: true
                sourceSize: Qt.size(window.width, window.height)
                opacity: 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: wallpaper.cfg.transitionMs
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.motion.curve.standard
                    }
                }
            }

            Layer {
                id: a
            }

            Layer {
                id: b
            }

            // Load into the hidden layer, fade it in when ready.
            function show(src) {
                const next = flip ? a : b;
                const prev = flip ? b : a;
                next.source = src;
                if (next.status === Image.Ready || !src)
                    swap(next, prev);
                else
                    next.statusChanged.connect(function h() {
                        if (next.status === Image.Ready || next.status === Image.Error) {
                            next.statusChanged.disconnect(h);
                            window.swap(next, prev);
                        }
                    });
            }

            function swap(next, prev) {
                next.opacity = next.source ? 1 : 0;
                prev.opacity = 0;
                flip = !flip;
            }

            onSourceChanged: show(source)
            Component.onCompleted: show(source)
        }
    }
}
