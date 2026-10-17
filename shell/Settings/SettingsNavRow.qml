import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// A row that leads somewhere (a subpage, a search hit): coloured icon tile,
// title, optional subtitle and a chevron. Put several in a SettingsNavList.
Item {
    id: row

    property string icon: ""
    // Section or page id for the tile colour (SettingsStyle.tileColor).
    property string tileId: ""
    property string title: ""
    property string subtitle: ""
    property bool divider: false

    signal clicked

    width: parent ? parent.width : 0
    implicitHeight: Math.max(tile.height, texts.implicitHeight) + SettingsStyle.rowPaddingY * 2

    SettingsDivider {
        visible: row.divider
        x: texts.x
        width: parent.width - x
    }

    StateLayer {
        anchors.fill: parent
        anchors.margins: SettingsStyle.groupInset
        radius: Theme.radius.md
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        focused: row.activeFocus
    }

    Rectangle {
        id: tile

        x: SettingsStyle.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.control.tile.size
        height: width
        radius: Theme.control.tile.radius
        color: SettingsStyle.tileColor(row.tileId)
        border.width: Theme.border.hairline
        border.color: Theme.color.innerBorder

        BIcon {
            anchors.centerIn: parent
            name: row.icon
            size: Theme.control.tile.icon
            color: Theme.color.tileIcon
        }
    }

    Column {
        id: texts

        anchors.left: tile.right
        anchors.leftMargin: Theme.space.lg
        anchors.right: chevron.left
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: SettingsStyle.descriptionSpacing

        BText {
            width: parent.width
            text: row.title
            role: "label"
            elide: Text.ElideRight
        }

        BText {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            role: "caption"
            tone: "muted"
            elide: Text.ElideRight
        }
    }

    BIcon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: SettingsStyle.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-right"
        size: Theme.icon.size.sm
        color: Theme.color.iconMuted
    }

    activeFocusOnTab: true
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
