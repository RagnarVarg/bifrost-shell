import QtQuick
import qs.Core

// NumberAnimation driven by motion tokens:
//   Behavior on x { BNumberAnimation { speed: "normal"; curve: "emphasized" } }
NumberAnimation {
    property string speed: "fast"
    property string curve: "standard"

    duration: Theme.motion.duration ? Theme.motion.duration[speed] : 0
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.motion.curve ? Theme.motion.curve[curve] : [0, 0, 1, 1, 1, 1]
}
