import QtQuick
import Quickshell
import qs.Core

// Top bar on every screen selected by bar.screens; in frame layout also the
// reservations for the frame's four sides.
Scope {
    readonly property var screens: Config.values.bar.screens || ["all"]
    readonly property var barScreens: Quickshell.screens.filter(s => Config.values.bar.enabled && (screens.indexOf("all") >= 0 || screens.indexOf(s.name) >= 0))

    Variants {
        model: barScreens

        delegate: BarWindow {}
    }

    Variants {
        model: Metrics.frame && RunMode.reservesScreenSpace ? barScreens : []

        delegate: Scope {
            id: frameScope

            required property var modelData
            readonly property string barEdge: Metrics.barEdge

            Instantiator {
                model: ["top", "bottom", "left", "right"]

                delegate: FrameReserve {
                    required property string modelData

                    screen: frameScope.modelData
                    edge: modelData
                    size: modelData === frameScope.barEdge ? Metrics.barHeight : Metrics.frameThickness
                }
            }
        }
    }
}
