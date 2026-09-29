import QtQuick
import qs.Core
import "Effects.js" as FX

// A faint prism wash (cyan → blue → violet, Theme.effects.prism) over a
// glass shape: one horizontal gradient, no shader. `strength` is its
// opacity, `saturation` scales the colours toward grey.
Rectangle {
    id: wash

    property real strength: 0.1
    property real saturation: 0.2
    // Fade out at both ends (when the shape runs on into other glass).
    property bool fadeEnds: false
    readonly property var stops: Theme.effects.prism || []

    visible: strength > 0 && stops.length >= 3
    opacity: strength
    antialiasing: true
    gradient: Gradient {
        orientation: Gradient.Horizontal

        GradientStop {
            position: 0
            color: wash.visible ? FX.tone(wash.stops[0], wash.saturation, wash.fadeEnds ? 0 : 1) : "transparent"
        }
        GradientStop {
            position: wash.fadeEnds ? 0.15 : 0
            color: wash.visible ? FX.tone(wash.stops[0], wash.saturation, 1) : "transparent"
        }
        GradientStop {
            position: 0.5
            color: wash.visible ? FX.tone(wash.stops[1], wash.saturation, 1) : "transparent"
        }
        GradientStop {
            position: wash.fadeEnds ? 0.85 : 1
            color: wash.visible ? FX.tone(wash.stops[2], wash.saturation, 1) : "transparent"
        }
        GradientStop {
            position: 1
            color: wash.visible ? FX.tone(wash.stops[2], wash.saturation, wash.fadeEnds ? 0 : 1) : "transparent"
        }
    }
}
