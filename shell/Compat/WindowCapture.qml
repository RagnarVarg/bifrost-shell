import QtQuick
import Quickshell.Wayland

// A live picture of one window (Quickshell screencopy of a Wayland toplevel,
// see Compositor.captureSource). Updates only while `live` and visible; the
// source stays set while hidden, so the last frame is kept and shown at once
// when it is visible again (dropping it would show nothing until the next
// capture arrives).
//   WindowCapture { source: Compositor.captureSource(win.id); live: menu.isOpen }
Item {
    id: root

    property var source: null
    property bool live: false
    readonly property bool hasContent: view.hasContent

    ScreencopyView {
        id: view

        anchors.fill: parent
        captureSource: root.source
        live: root.live && root.visible
    }
}
