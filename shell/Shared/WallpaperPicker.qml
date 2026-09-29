import QtQuick
import QtQuick.Controls
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text

Column {
    id: picker

    signal backRequested()
    property bool showHeader: true
    property real viewportHeight: 0
    property string applyError: ""
    spacing: Theme.space.md

    Component.onCompleted: Wallpapers.retain()
    Component.onDestruction: Wallpapers.release()

    Row {
        id: header
        visible: picker.showHeader
        width: parent.width
        spacing: Theme.space.md
        BButton {
            text: I18n.tr("Back")
            size: "sm"
            onClicked: picker.backRequested()
        }
        BText {
            text: "Wallpaper"
            role: "heading"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    BText {
        id: hint
        width: parent.width
        text: I18n.tr("Choose an image to apply it immediately")
        role: "caption"
        tone: "muted"
        wrapMode: Text.Wrap
    }

    GridView {
        id: grid
        width: parent.width
        height: picker.viewportHeight > 0
            ? Math.max(0, picker.viewportHeight - hint.height - picker.spacing
                - (header.visible ? header.height + picker.spacing : 0)
                - (emptyMessage.visible ? emptyMessage.height + picker.spacing : 0)
                - (errorMessage.visible ? errorMessage.height + picker.spacing : 0))
            : Math.min(360, Math.max(cellHeight, contentHeight))
        clip: true
        cellWidth: width / 3
        cellHeight: cellWidth * 9 / 16 + Theme.space.xl
        model: Wallpapers.images
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        delegate: Item {
            id: tile
            required property string modelData
            readonly property bool current: Wallpapers.source === Wallpapers.fileUrl(modelData)
            width: grid.cellWidth
            height: grid.cellHeight

            Item {
                anchors.fill: parent
                anchors.margins: Theme.space.xs

                Image {
                    id: preview
                    width: parent.width
                    height: width * 9 / 16
                    source: Wallpapers.fileUrl(tile.modelData)
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                BText {
                    anchors.centerIn: preview
                    visible: preview.status === Image.Error
                    text: I18n.tr("Preview unavailable")
                    width: parent.width
                    wrapMode: Text.Wrap
                    role: "caption"
                }
                BText {
                    anchors.top: preview.bottom
                    width: parent.width
                    text: (tile.current ? "✓ " : "") + tile.modelData.split("/").pop()
                    elide: Text.ElideMiddle
                    role: "caption"
                }
                StateLayer {
                    anchors.fill: parent
                    radius: Theme.radius.sm
                    hovered: mouse.containsMouse
                    selected: tile.current
                    focused: tile.current || tile.activeFocus
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.applyError = Wallpapers.apply(tile.modelData)
                }
            }
            activeFocusOnTab: true
            Keys.onReturnPressed: picker.applyError = Wallpapers.apply(modelData)
            Keys.onSpacePressed: picker.applyError = Wallpapers.apply(modelData)
            Accessible.role: Accessible.Button
            Accessible.name: modelData.split("/").pop()
            Accessible.description: current ? I18n.tr("Current wallpaper") : ""
            Accessible.onPressAction: picker.applyError = Wallpapers.apply(modelData)
        }
    }

    BText {
        id: emptyMessage
        width: parent.width
        visible: Wallpapers.images.length === 0
        text: Wallpapers.scanning ? I18n.tr("Loading wallpapers…") : I18n.tr("No wallpapers found. Add images to ~/Pictures/Wallpapers or your configured wallpaper folder.")
        wrapMode: Text.Wrap
        role: "caption"
        tone: "muted"
    }
    BText {
        id: errorMessage
        width: parent.width
        visible: text !== ""
        text: picker.applyError || Wallpapers.scanError
        wrapMode: Text.Wrap
        role: "caption"
    }
}
