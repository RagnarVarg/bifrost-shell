import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Components.Glass
import qs.Components.Motion
import qs.Modules
import qs.Services

// Popups on the focused screen at notifications.position. Only the cards
// take input. Each popup hides after its timeout (critical ones stay).
Scope {
    PanelWindow {
        id: window

        readonly property string position: Config.values.notifications.position
        readonly property bool atBottom: position.startsWith("bottom")

        screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen()) || Quickshell.screens[0]
        visible: Notify.popups.length > 0
        color: "transparent"
        WlrLayershell.namespace: RunMode.layerNamespace("notifications")
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors.top: !atBottom
        anchors.bottom: atBottom
        anchors.left: position.endsWith("left")
        anchors.right: position.endsWith("right")
        margins.top: atBottom ? 0 : Metrics.edgeSpace("top")
        margins.bottom: atBottom ? Metrics.edgeSpace("bottom") : 0
        margins.left: Theme.space.md + Metrics.edgeSpace("left")
        margins.right: Theme.space.md + Metrics.edgeSpace("right")
        implicitWidth: Theme.layout.notificationWidth + Theme.space.xxxl * 2
        implicitHeight: Math.max(1, stack.implicitHeight + Theme.space.xxxl * 2)

        mask: Region {
            item: stack
        }

        Column {
            id: stack

            x: Theme.space.xxxl
            y: Theme.space.lg
            width: Theme.layout.notificationWidth
            spacing: Theme.space.md

            Repeater {
                model: window.atBottom ? Notify.popups.slice().reverse() : Notify.popups

                delegate: GlassSurface {
                    id: popup

                    required property var modelData

                    material: Theme.materials.notifications
                    width: stack.width
                    height: card.implicitHeight
                    opacity: 0

                    Component.onCompleted: opacity = 1

                    Behavior on opacity {
                        BNumberAnimation {}
                    }

                    NotificationCard {
                        id: card

                        anchors.fill: parent
                        item: popup.modelData
                        popup: true
                        onCloseRequested: Notify.dismiss(popup.modelData.id)
                    }

                    // Click the body to move it to the center.
                    TapHandler {
                        onTapped: Notify.hidePopup(popup.modelData.id)
                    }

                    Timer {
                        running: !popup.modelData.critical && !hover.hovered
                        interval: popup.modelData.timeout > 0 ? popup.modelData.timeout : Config.values.notifications.timeoutMs
                        onTriggered: Notify.hidePopup(popup.modelData.id)
                    }

                    HoverHandler {
                        id: hover
                    }
                }
            }
        }
    }
}
