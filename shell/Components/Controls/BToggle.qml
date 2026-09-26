import QtQuick
import qs.Core
import qs.Components.Motion
import qs.Components.State

// Switch. Emits toggled(checked) on user interaction; `checked` is not
// changed internally so it can stay bound to Config.
Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    readonly property var dims: Theme.control.toggle

    implicitWidth: dims.width
    implicitHeight: dims.height
    opacity: enabled ? 1 : Theme.opacity.disabled
    activeFocusOnTab: true

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.color.trackActive : Theme.color.track
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline

        Behavior on color {
            BColorAnimation {}
        }
    }

    StateLayer {
        anchors.fill: parent
        radius: height / 2
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        focused: root.activeFocus
    }

    Rectangle {
        id: knob

        readonly property real inset: (root.height - root.dims.knob) / 2

        width: root.dims.knob
        height: root.dims.knob
        radius: width / 2
        y: inset
        x: root.checked ? root.width - width - inset : inset
        color: Theme.color.knob

        Behavior on x {
            BNumberAnimation {
                speed: "normal"
                curve: "emphasized"
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    Keys.onSpacePressed: toggled(!checked)
}
