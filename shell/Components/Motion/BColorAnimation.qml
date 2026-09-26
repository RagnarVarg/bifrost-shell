import QtQuick
import qs.Core

// ColorAnimation driven by motion tokens (see BNumberAnimation).
ColorAnimation {
    property string speed: "fast"
    property string curve: "standard"

    duration: Theme.motion.duration ? Theme.motion.duration[speed] : 0
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.motion.curve ? Theme.motion.curve[curve] : [0, 0, 1, 1, 1, 1]
}
