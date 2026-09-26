import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core

// Reserves screen space along one edge for the frame (layer-shell can't
// reserve for a surface anchored to all four edges, which the frame is).
// Invisible and click-through.
PanelWindow {
    id: reserve

    property string edge: "top"
    property real size: 0

    WlrLayershell.namespace: RunMode.layerNamespace("frame-reserve")
    WlrLayershell.layer: WlrLayer.Bottom
    color: "transparent"
    mask: Region {}

    anchors.top: edge !== "bottom"
    anchors.bottom: edge !== "top"
    anchors.left: edge !== "right"
    anchors.right: edge !== "left"

    implicitWidth: 1
    implicitHeight: 1
    exclusiveZone: Math.max(0, Math.round(size))
}
