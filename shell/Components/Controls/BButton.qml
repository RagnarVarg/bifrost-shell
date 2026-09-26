import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text

// Button. variant: primary | secondary | ghost; size: sm | md | lg.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "secondary"
    property string size: "md"
    property bool selected: false

    signal clicked

    readonly property bool primary: variant === "primary"
    readonly property color contentColor: primary ? Theme.color.onAccent : Theme.color.text

    implicitHeight: Theme.control.height[size]
    implicitWidth: row.implicitWidth + Theme.control.paddingX * 2
    opacity: enabled ? 1 : Theme.opacity.disabled
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.control.radius
        color: root.primary ? Theme.color.accent : root.variant === "secondary" ? Theme.color.controlFill : "transparent"
        border.width: root.variant === "secondary" ? Theme.border.hairline : 0
        border.color: Theme.color.hairline

        Behavior on color {
            BColorAnimation {}
        }
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.control.radius
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: root.selected
        focused: root.activeFocus
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space.sm

        BIcon {
            visible: root.icon !== ""
            name: root.icon
            size: Theme.icon.size.sm
            color: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
        }

        BText {
            visible: root.text !== ""
            text: root.text
            role: "label"
            color: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
}
