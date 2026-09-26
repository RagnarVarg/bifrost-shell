import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State

// Square icon button; `selected` shows the persistent (prism) state.
Item {
    id: root

    property string icon: ""
    property string size: "md"
    property bool selected: false
    property bool active: false

    signal clicked

    implicitWidth: Theme.control.height[size]
    implicitHeight: Theme.control.height[size]
    opacity: enabled ? 1 : Theme.opacity.disabled
    activeFocusOnTab: true

    StateLayer {
        anchors.fill: parent
        radius: Theme.control.radius
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: root.selected
        active: root.active
        focused: root.activeFocus
    }

    BIcon {
        anchors.centerIn: parent
        name: root.icon
        size: root.size === "sm" ? Theme.icon.size.sm : Theme.icon.size.md
        color: root.selected || root.active ? Theme.color.text : Theme.color.icon
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Keys.onSpacePressed: clicked()
}
