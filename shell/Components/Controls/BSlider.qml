import QtQuick
import qs.Core
import qs.Components.State

// Horizontal slider. Emits moved(value) while dragging; `value` is not
// changed internally so it can stay bound to Config.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0

    signal moved(real value)

    readonly property var dims: Theme.control.slider
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    implicitWidth: dims.height * 8
    implicitHeight: dims.height
    opacity: enabled ? 1 : Theme.opacity.disabled
    activeFocusOnTab: true

    function valueAt(x) {
        const r = Math.max(0, Math.min(1, (x - dims.knob / 2) / (width - dims.knob)));
        let v = from + r * (to - from);
        if (stepSize > 0)
            v = Math.round((v - from) / stepSize) * stepSize + from;
        return Math.max(from, Math.min(to, v));
    }

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        x: root.dims.knob / 2
        width: root.width - root.dims.knob
        height: root.dims.track
        radius: height / 2
        color: Theme.color.track

        Rectangle {
            width: parent.width * root.ratio
            height: parent.height
            radius: parent.radius
            color: Theme.color.trackActive
        }
    }

    Item {
        id: knob

        width: root.dims.knob
        height: root.dims.knob
        anchors.verticalCenter: parent.verticalCenter
        x: root.ratio * (root.width - width)

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.color.knob
        }

        StateLayer {
            anchors.fill: parent
            anchors.margins: -Theme.space.xs
            radius: width / 2
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: e => root.moved(root.valueAt(e.x))
        onPositionChanged: e => {
            if (pressed)
                root.moved(root.valueAt(e.x));
        }
    }

    Keys.onLeftPressed: moved(Math.max(from, value - (stepSize || (to - from) / 20)))
    Keys.onRightPressed: moved(Math.min(to, value + (stepSize || (to - from) / 20)))
}
