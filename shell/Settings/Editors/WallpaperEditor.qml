import QtQuick
import qs.Compat
import qs.Services
import qs.Core
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text

// Uses the same discovery service as the clock menu.
EditorBase {
    id: editor

    readonly property var images: Wallpapers.images
    readonly property real thumbWidth: Theme.space.xxxl * 4
    readonly property real thumbHeight: thumbWidth * 9 / 16

    wide: true
    implicitWidth: Theme.layout.pageMaxWidth
    implicitHeight: images.length ? grid.implicitHeight : empty.implicitHeight

    Component.onCompleted: Wallpapers.retain()
    Component.onDestruction: Wallpapers.release()

    BText {
        id: empty

        visible: editor.images.length === 0
        text: Wallpapers.scanError || (Wallpapers.scanning ? I18n.tr("Loading wallpapers…") : I18n.tr("No wallpapers found"))
        role: "caption"
        tone: "muted"
    }

    Flow {
        id: grid

        width: parent.width
        spacing: Theme.space.sm

        Repeater {
            model: editor.images

            delegate: Item {
                id: thumb

                required property string modelData
                readonly property bool current: Platform.expandHome(editor.value || "") === modelData

                width: editor.thumbWidth
                height: editor.thumbHeight

                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.space.xxs
                    source: Wallpapers.fileUrl(thumb.modelData)
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                StateLayer {
                    anchors.fill: parent
                    radius: Theme.radius.sm
                    hovered: mouse.containsMouse
                    selected: thumb.current
                    focused: thumb.current
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editor.set(thumb.modelData)
                }
            }
        }
    }
}
