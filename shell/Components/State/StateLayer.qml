import QtQuick
import qs.Core

// Interaction states for any control, from Theme.states:
//   selected / active  → persistent base layer (prism by default, glow with selection "glow")
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
    // "prism" (theme default) or "glow": glowing accent colour for selected / active.
    property string selection: "prism"
    readonly property bool glow: selection === "glow"
    // Glow colour; empty = the state's own (accent).
    property string glowColor: ""

    function tinted(spec) {
        return glowColor ? Object.assign({}, spec, { color: glowColor }) : spec;
    }

    StateFill {
        anchors.fill: parent
        radius: root.radius
        intensityScale: root.intensityScale
        spec: root.active ? (root.glow ? root.tinted(Theme.states.glowActive) : Theme.states.active) : root.selected ? (root.glow ? root.tinted(Theme.states.glowSelected) : Theme.states.selected) : null
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
