import QtQuick
import qs.Core

// Monochrome line icon from assets/icons/<name>.svg, recoloured from tokens.
//   BIcon { name: "wifi"; size: Theme.icon.size.md; color: Theme.color.icon }
// `source` may point at any white SVG (e.g. the brand mark).
Item {
    id: root

    property string name: ""
    property url source: name ? "file://" + Paths.assetsDir + "/icons/" + name + ".svg" : ""
    property real size: Theme.icon.size.md
    property color color: Theme.color.icon

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        property variant source: image
        property vector4d color: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)

        fragmentShader: Qt.resolvedUrl("../Shaders/tint.frag.qsb")
    }
}
