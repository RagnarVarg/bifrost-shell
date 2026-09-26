import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// One row in a bar menu: a line icon (`icon`) or an app/file image
// (`image`), a label, and trailing detail text or a chevron for submenus.
// `armed` marks a row that waits for a confirming second click.
// A row with `separator: true` is a divider instead.
Item {
    id: row

    property string icon: ""
    property url image: ""
    property string text: ""
    property string detail: ""
    property bool submenu: false
    property bool armed: false
    property bool separator: false

    signal clicked

    width: parent ? parent.width : implicitWidth
    implicitWidth: Theme.space.xxxl * 9
    height: separator ? Theme.space.md : Theme.control.height.md

    BDivider {
        visible: row.separator
        anchors.centerIn: parent
        width: parent.width - Theme.space.md * 2
    }

    StateLayer {
        visible: !row.separator
        anchors.fill: parent
        radius: Theme.control.radius
        hovered: mouse.containsMouse && row.enabled
        pressed: mouse.pressed
        active: row.armed
    }

    Row {
        visible: !row.separator
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.right: trailing.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.md
        opacity: row.enabled ? 1 : Theme.opacity.disabled

        Item {
            width: Theme.icon.size.sm
            height: Theme.icon.size.sm
            anchors.verticalCenter: parent.verticalCenter

            BIcon {
                anchors.fill: parent
                visible: row.icon !== ""
                name: row.icon
                size: Theme.icon.size.sm
                color: row.armed ? Theme.color.danger : mouse.containsMouse && row.enabled ? Theme.color.text : Theme.color.icon
            }

            Image {
                anchors.fill: parent
                visible: row.icon === "" && row.image != ""
                source: row.image
                sourceSize: Qt.size(width * 2, height * 2)
                smooth: true
            }
        }

        BText {
            width: parent.width - Theme.icon.size.sm - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            role: "label"
            tone: row.armed ? "danger" : "primary"
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailing

        visible: !row.separator
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        width: row.submenu ? chevron.width : detailText.implicitWidth
        height: parent.height
        opacity: row.enabled ? 1 : Theme.opacity.disabled

        BText {
            id: detailText

            visible: !row.submenu && text !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.detail
            role: "caption"
            tone: "faint"
        }

        BIcon {
            id: chevron

            visible: row.submenu
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-right"
            size: Theme.icon.size.sm
            color: Theme.color.textFaint
        }
    }

    MouseArea {
        id: mouse

        visible: !row.separator
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.clicked()
    }
}
