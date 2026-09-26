import QtQuick
import qs.Core

// Interaction states for any control, from Theme.states:
//   selected / active  → persistent base layer (prism by default)
//   hover / pressed    → transient layer on top
//   focused            → ring
// Controls set the booleans; they never draw state colours themselves.
Item {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool active: false
    property bool focused: false
    property real radius: Theme.control.radius
    // Lets demos compare prism strengths; normal UI leaves it at 1.
    property real intensityScale: 1

    StateFill {
        anchors.fill: parent
        radius: root.radius
        intensityScale: root.intensityScale
        spec: root.active ? Theme.states.active : root.selected ? Theme.states.selected : null
    }

    StateFill {
        anchors.fill: parent
        radius: root.radius
        spec: root.pressed ? Theme.states.pressed : root.hovered ? Theme.states.hover : null
    }

    StateFill {
        anchors.fill: parent
        radius: root.radius
        intensityScale: root.intensityScale
        spec: root.focused ? Theme.states.focus : null
    }
}
