import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// One sidebar entry.
Item {
    id: item

    property string icon: ""
    property string label: ""
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

    BIcon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        name: item.icon
        size: Theme.icon.size.sm
        color: item.current ? Theme.color.text : Theme.color.iconMuted
    }

    BText {
        anchors.left: glyph.right
        anchors.leftMargin: Theme.space.md
        anchors.right: count.left
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
