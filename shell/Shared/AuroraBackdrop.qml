import QtQuick
import qs.Core
import qs.Components.Icons

// The dark field with a faint aurora glow and the Bifrost mark behind the
// lock screen, and the login screen when there is no wallpaper.
Item {
    property bool mark: true    // the Bifrost mark in the middle
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.palette.void
            }
            GradientStop {
                position: 1
                color: Theme.palette.base
            }
        }
    }

    // Faint aurora glow rising from the bottom edge: the only colour here.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.45
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.prism.stops[1], Theme.opacity.stateHover)
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.border.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.3
                color: Qt.alpha(Theme.prism.stops[0], Theme.opacity.innerBorder)
            }
            GradientStop {
                position: 0.5
                color: Qt.alpha(Theme.prism.stops[1], Theme.opacity.innerBorder)
            }
            GradientStop {
                position: 0.7
                color: Qt.alpha(Theme.prism.stops[2], Theme.opacity.innerBorder)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    BIcon {
        visible: parent.mark
        anchors.centerIn: parent
        source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
        size: Math.min(parent.width, parent.height) * 0.5
        color: Qt.alpha(Theme.palette.silver, Theme.opacity.controlFill)
    }
}
