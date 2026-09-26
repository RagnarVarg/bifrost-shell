import QtQuick
import qs.Core
import qs.Components.Motion

// Draws one interaction state spec from Theme.states:
//   fill "solid" → translucent colour, "prism" → Bifrost prism, "ring" → rim only.
// Fades in/out with motion tokens; keeps the last spec while fading out.
Item {
    id: root

    property var spec: null
    property real radius: Theme.control.radius
    property real intensityScale: 1

    property var shown: spec
    readonly property bool usePrism: shown !== null && (shown.fill === "prism" || shown.fill === "ring")
    readonly property real intensity: shown ? (shown.prism || 0) * intensityScale : 0

    readonly property color specColor: shown ? shown.color : "transparent"
    readonly property color stop0: Theme.prism.stops[0]
    readonly property color stop1: Theme.prism.stops[1]
    readonly property color stop2: Theme.prism.stops[2]

    function vec(c) {
        return Qt.vector4d(c.r, c.g, c.b, c.a);
    }

    onSpecChanged: if (spec)
        shown = spec
    opacity: spec ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        BNumberAnimation {}
    }

    Rectangle {
        anchors.fill: parent
        visible: root.shown !== null && root.shown.fill === "solid"
        radius: root.radius
        color: Qt.alpha(root.specColor, root.shown && root.shown.opacity !== undefined ? root.shown.opacity : 0)
    }

    ShaderEffect {
        id: prism

        anchors.fill: parent
        visible: root.usePrism

        property vector2d itemSize: Qt.vector2d(width, height)
        property real radius: root.radius
        property vector4d baseColor: root.vec(root.specColor)
        property real baseOpacity: root.shown && root.shown.fill === "ring" ? 1 : (root.shown ? root.shown.opacity : 0)
        property real intensity: root.intensity
        property vector4d stop0: root.vec(root.stop0)
        property vector4d stop1: root.vec(root.stop1)
        property vector4d stop2: root.vec(root.stop2)
        property real angle: Theme.prism.angle
        property real spread: Theme.prism.spread
        property real tintAmount: Theme.prism.tint
        property real caustic: Theme.prism.caustic
        property real edge: Theme.prism.edge
        property real edgeWidth: root.shown && root.shown.fill === "ring" ? root.shown.width : Theme.prism.edgeWidth
        property real dispersion: Theme.prism.dispersion
        property real phase: 0
        property real mode: root.shown && root.shown.fill === "ring" ? 1 : 0

        fragmentShader: Qt.resolvedUrl("../Shaders/prism.frag.qsb")

        NumberAnimation on phase {
            from: 0
            to: 1
            duration: Theme.prism.driftSeconds * 1000
            loops: Animation.Infinite
            running: prism.visible && Theme.prism.driftSeconds > 0 && Theme.motion.enabled
        }
    }
}
