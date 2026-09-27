import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Toggle tile: icon, title, status line. `on` uses the selected (prism) state.
Item {
    id: tile

    property string icon: ""
    property string title: ""
    property string status: ""
    property bool on: false
    property bool busy: false
    // Shows a chevron that opens a detail view (e.g. Bluetooth devices).
    property bool expandable: false
    property bool expanded: false

    signal clicked
    signal expand

    implicitHeight: Theme.control.height.lg + Theme.space.lg
    opacity: enabled ? 1 : Theme.opacity.disabled

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.lg
        // Glass & transparency → Control center buttons.
        color: Theme.materials.controlButtons.fill
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.radius.lg
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: tile.on
    }

    BIcon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        name: tile.icon
        size: Theme.icon.size.md
        color: tile.on ? Theme.color.text : Theme.color.iconMuted
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: Theme.space.md
        anchors.right: tile.expandable ? chevron.left : parent.right
        anchors.rightMargin: tile.expandable ? Theme.space.xs : Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.xxs

        BText {
            width: parent.width
            text: tile.title
            role: "label"
            elide: Text.ElideRight
        }

        BText {
            width: parent.width
            text: tile.busy ? "…" : tile.status
            role: "caption"
            tone: tile.on ? "primary" : "muted"
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }

    BIconButton {
        id: chevron

        visible: tile.expandable
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.xs
        anchors.verticalCenter: parent.verticalCenter
        size: "sm"
        icon: tile.expanded ? "chevron-down" : "chevron-right"
        selected: tile.expanded
        z: 1
        onClicked: tile.expand()
    }
}
