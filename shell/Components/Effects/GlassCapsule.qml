import QtQuick
import qs.Core

// A discreet glass capsule: a faint light fill and a 1 px light rim, fully
// rounded. Drawn inside an existing glass, so it has no blur of its own.
Rectangle {
    readonly property color light: Theme.effects.highlightColor || "white"

    radius: height / 2
    antialiasing: true
    color: Theme.alpha(light, Theme.effects.capsuleFill ?? 0)
    border.width: Theme.effects.lineWidth ?? 1
    border.color: Theme.alpha(light, Theme.effects.capsuleBorder ?? 0)
}
