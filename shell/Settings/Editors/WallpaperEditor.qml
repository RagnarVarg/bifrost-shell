import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text

// Thumbnails of the images in wallpaper.directory; click to choose.
EditorBase {
    id: editor

    property var images: []
    readonly property string directory: Platform.expandHome(Config.values.wallpaper.directory || "")
    readonly property real thumbWidth: Theme.space.xxxl * 4
    readonly property real thumbHeight: thumbWidth * 9 / 16

    wide: true
    implicitWidth: Theme.layout.pageMaxWidth
    implicitHeight: images.length ? grid.implicitHeight : empty.implicitHeight

    function scan() {
        Exec.run(["find", directory, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"], (code, out) => {
            editor.images = out.split("\n").filter(f => f).sort();
        }, 5000, editor);
    }

    onDirectoryChanged: scan()
    Component.onCompleted: scan()

    BText {
        id: empty

        visible: editor.images.length === 0
        text: I18n.tr("No images in %1").arg(editor.directory)
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
                    source: "file://" + thumb.modelData
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
