import QtQuick
import qs.Core

// A vertical light-to-dark shade over a glass shape: a touch lighter at the
// top, a touch darker at the bottom, clear in between. `strength` is the
// alpha at both ends.
Rectangle {
    id: shade

    property real strength: 0.08
    property color lightColor: Theme.effects.highlightColor || "white"
    property color darkColor: Theme.effects.edgeColor || "black"

    visible: strength > 0
    antialiasing: true
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Theme.alpha(shade.lightColor, shade.strength)
        }
        GradientStop {
            position: 0.45
            color: Theme.alpha(shade.lightColor, 0)
        }
        GradientStop {
            position: 0.6
            color: Theme.alpha(shade.darkColor, 0)
        }
        GradientStop {
            position: 1
            color: Theme.alpha(shade.darkColor, shade.strength)
        }
    }
}
