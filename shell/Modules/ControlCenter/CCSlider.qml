import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Icon button + slider + percent, e.g. volume with mute. With `expandable`
// the label (e.g. the output device) opens a detail view below, like
// CCTile's chevron.
Item {
    id: row

    property string icon: ""
    property string label: ""
    property real value: 0
    property bool muted: false
    property bool expandable: false
    property bool expanded: false

    signal moved(real value)
    signal iconClicked
    signal expand

    implicitHeight: Theme.control.height.md + (caption.visible ? Math.max(caption.implicitHeight, expandable ? Theme.control.height.sm : 0) : 0)

    BIconButton {
        id: button

        icon: row.icon
        selected: row.muted
        anchors.verticalCenter: slider.verticalCenter
        onClicked: row.iconClicked()
    }

    BSlider {
        id: slider

        anchors.left: button.right
        anchors.leftMargin: Theme.space.sm
        anchors.right: readout.left
        anchors.rightMargin: Theme.space.md
        height: Theme.control.height.md
        value: row.value
        opacity: row.muted ? Theme.opacity.disabled : 1
        onMoved: v => row.moved(v)
    }

    BText {
        id: readout

        anchors.right: parent.right
        anchors.verticalCenter: slider.verticalCenter
        width: Theme.space.xxxl * 1.3
        horizontalAlignment: Text.AlignRight
        text: row.muted ? I18n.tr("off") : Math.round(row.value * 100) + "%"
        role: "mono"
        tone: row.muted ? "faint" : "muted"
    }

    BText {
        id: caption

        visible: row.label !== ""
        anchors.top: slider.bottom
        anchors.left: slider.left
        anchors.right: row.expandable ? chevron.left : slider.right
        anchors.topMargin: row.expandable ? (Theme.control.height.sm - implicitHeight) / 2 : 0
        text: row.label
        role: "caption"
        tone: row.expanded || labelMouse.containsMouse ? "muted" : "faint"
        elide: Text.ElideRight

        MouseArea {
            id: labelMouse

            anchors.fill: parent
            enabled: row.expandable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.expand()
        }
    }

    BIconButton {
        id: chevron

        visible: row.expandable && row.label !== ""
        anchors.top: slider.bottom
        anchors.right: parent.right
        size: "sm"
        icon: row.expanded ? "chevron-down" : "chevron-right"
        selected: row.expanded
        onClicked: row.expand()
    }
}
