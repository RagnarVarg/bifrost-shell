import QtQuick
import qs.Core
import qs.Components.State
import qs.Components.Text

// Segmented control. The current segment carries the "selected" (prism) state.
Item {
    id: root

    property var model: []          // strings
    property int currentIndex: 0
    property string size: "md"

    signal activated(int index)

    implicitHeight: Math.max(Theme.control.height[size], row.implicitHeight + Theme.space.xs * 2)
    implicitWidth: row.children.reduce((sum, child) => sum + (child.implicitWidth || 0), 0) + Math.max(0, model.length - 1) * Theme.space.xxs + Theme.space.xs * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.control.radius
        color: Theme.color.controlFill
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline
    }

    Flow {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space.xs
        spacing: Theme.space.xxs

        Repeater {
            model: root.model

            delegate: Item {
                id: segment

                required property int index
                required property var modelData

                implicitWidth: label.implicitWidth + Theme.control.paddingX * 2
                width: Math.max(0, Math.min(implicitWidth, row.width))
                height: Math.max(Theme.control.height[root.size] - Theme.space.xs * 2, label.implicitHeight + Theme.space.xs * 2)

                StateLayer {
                    anchors.fill: parent
                    radius: Theme.control.radius - Theme.space.xs
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                    selected: segment.index === root.currentIndex
                }

                BText {
                    id: label

                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Theme.control.paddingX * 2)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: segment.modelData
                    role: "label"
                    tone: segment.index === root.currentIndex ? "primary" : "muted"
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(segment.index)
                }
            }
        }
    }
}
