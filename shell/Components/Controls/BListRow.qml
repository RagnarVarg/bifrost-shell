import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Settings-style row: icon, title, optional subtitle, trailing content
// (children go to the trailing slot, e.g. a BToggle).
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool selected: false
    property bool interactive: true

    default property alias trailing: trailingSlot.data

    signal clicked

    implicitHeight: Math.max(Theme.control.height.lg, texts.implicitHeight + Theme.space.md * 2)
    implicitWidth: Theme.control.height.lg * 8

    StateLayer {
        anchors.fill: parent
        radius: Theme.radius.md
        hovered: root.interactive && mouse.containsMouse
        pressed: root.interactive && mouse.pressed
        selected: root.selected
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        onClicked: root.clicked()
    }

    BIcon {
        id: iconItem

        visible: root.icon !== ""
        name: root.icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        color: root.selected ? Theme.color.text : Theme.color.icon
    }

    Column {
        id: texts

        anchors.left: iconItem.visible ? iconItem.right : parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.right: trailingSlot.left
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.xxs

        BText {
            width: parent.width
            text: root.title
            role: "label"
            elide: Text.ElideRight
        }

        BText {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            role: "caption"
            tone: "muted"
            elide: Text.ElideRight
        }
    }

    Row {
        id: trailingSlot

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.md
    }
}
