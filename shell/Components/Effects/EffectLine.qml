import QtQuick
import qs.Core
import "Effects.js" as FX

// A thin horizontal line whose outer ends fade out, e.g. a glass highlight
// or a dark bottom edge. `gapStart`/`gapWidth` cut a span out of it (where a
// menu grows out of the glass, so no line crosses the seam).
//
//   EffectLine { width: …; color: Theme.alpha(Theme.effects.highlightColor, 0.2) }
Item {
    id: line

    property color color: "transparent"
    // Share of the whole length that fades in at each outer end.
    property real fade: Theme.effects.lineFade ?? 0
    property real gapStart: 0
    property real gapWidth: 0

    implicitHeight: Theme.effects.lineWidth ?? 1
    visible: color.a > 0

    Repeater {
        model: FX.segments(line.width, line.gapStart, line.gapWidth)

        delegate: Rectangle {
            id: segment

            required property var modelData

            readonly property real fadePx: line.width * line.fade
            readonly property bool fadeStart: modelData[0] <= 0
            readonly property bool fadeEnd: modelData[1] >= line.width

            x: modelData[0]
            width: modelData[1] - modelData[0]
            height: line.height
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: segment.fadeStart ? "transparent" : line.color
                }
                GradientStop {
                    position: segment.fadeStart && segment.width > 0 ? Math.min(0.5, segment.fadePx / segment.width) : 0
                    color: line.color
                }
                GradientStop {
                    position: segment.fadeEnd && segment.width > 0 ? Math.max(0.5, 1 - segment.fadePx / segment.width) : 1
                    color: line.color
                }
                GradientStop {
                    position: 1
                    color: segment.fadeEnd ? "transparent" : line.color
                }
            }
        }
    }
}
