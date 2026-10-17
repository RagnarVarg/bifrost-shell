import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// One sidebar entry: a coloured icon tile, the label and a count of
// modified settings.
Item {
    id: item

    property string icon: ""
    property string label: ""
    // Section or page id: picks the tile colour (SettingsStyle.tileColor).
    property string pageId: ""
    property int badge: 0
    property bool current: false

    signal clicked

    width: parent ? parent.width : 0
    height: Theme.control.height.md

    StateLayer {
        anchors.fill: parent
        radius: Theme.control.radius
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: item.current
    }

    Rectangle {
        id: tile

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.control.tile.size
        height: width
        radius: Theme.control.tile.radius
        color: SettingsStyle.tileColor(item.pageId)
        border.width: Theme.border.hairline
        border.color: Theme.color.innerBorder

        BIcon {
            anchors.centerIn: parent
            name: item.icon
            size: Theme.control.tile.icon
            color: Theme.color.tileIcon
        }
    }

    BText {
        anchors.left: tile.right
        anchors.leftMargin: Theme.space.md
        anchors.right: count.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        text: item.label
        role: "label"
        tone: item.current ? "primary" : "muted"
        elide: Text.ElideRight
    }

    BText {
        id: count

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        visible: item.badge > 0
        width: visible ? implicitWidth : 0
        text: item.badge
        role: "mono"
        tone: "accent"
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}
