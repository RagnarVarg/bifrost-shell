import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Small pill: filters, tags, status. `selected` shows the prism state.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property bool selected: false

    signal clicked

    implicitHeight: Theme.control.chip.height
    implicitWidth: row.implicitWidth + Theme.space.lg * 2

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Theme.control.chip.radius, height / 2)
        color: Theme.color.controlFill
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline
    }

    StateLayer {
        anchors.fill: parent
        radius: Math.min(Theme.control.chip.radius, height / 2)
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: root.selected
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space.xs

        BIcon {
            visible: root.icon !== ""
            name: root.icon
            size: Theme.icon.size.sm
            anchors.verticalCenter: parent.verticalCenter
        }

        BText {
            text: root.text
            role: "caption"
            tone: root.selected ? "primary" : "muted"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
