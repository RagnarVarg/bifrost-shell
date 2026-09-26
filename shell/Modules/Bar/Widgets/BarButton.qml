import QtQuick
import qs.Core
import qs.Components.State

// Clickable area inside the bar with shared state styling. Put content in it.
Item {
    id: button

    property bool selected: false
    property bool active: false
    property real padding: Theme.space.md
    // Content stacked (a side bar's upright widget).
    property bool vertical: false
    property real spacing: Theme.space.sm
    property alias hovered: mouse.containsMouse
    property alias acceptedButtons: mouse.acceptedButtons

    default property alias content: row.data

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: vertical ? Math.max(Theme.control.height.sm, row.implicitHeight + padding * 2) : Theme.control.height.sm

    StateLayer {
        anchors.fill: parent
        radius: Math.min(Theme.control.radius, height / 2)
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: button.selected
        active: button.active
    }

    BarRow {
        id: row

        anchors.centerIn: parent
        vertical: button.vertical
        spacing: button.spacing
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m => button.clicked(m)
        onWheel: w => button.wheel(w)
    }
}
