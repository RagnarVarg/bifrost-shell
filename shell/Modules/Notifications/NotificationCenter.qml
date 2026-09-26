import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Motion
import qs.Components.Popup
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar
import qs.Services

// Notification center (NotificationCenterContent). Normally the bell's bar
// menu, grown out of the bar (NotificationsWidget, PanelMenu); this window
// under the bar's end is for a screen whose bar has no bell.
Scope {
    id: center

    readonly property bool open: ShellState.notificationCenterOpen
    readonly property var bar: Config.values.bar
    readonly property var anchor: ShellState.notificationCenterAnchor
    readonly property bool anchorHovered: anchor !== null && anchor.item !== null && anchor.item.hovered === true
    readonly property bool ownWindow: Placement.barHost("notificationCenter", ShellState.notificationCenterScreen) === null

    function close() {
        ShellState.notificationCenterOpen = false;
    }

    onOpenChanged: {
        if (open) {
            leave.reset();
            Notify.markRead();
        } else {
            ShellState.notificationCenterAnchor = null;
        }
    }

    LeaveWatch {
        id: leave

        active: center.open && center.ownWindow
        pointerInside: panelHover.hovered || center.anchorHovered
        screenName: window.screen ? window.screen.name : ""
        rects: () => window.leaveRects()
        onLeft: center.close()
    }

    PanelWindow {
        id: window

        // In the corner at the bar's end: top right, bottom right for a
        // bottom bar, top left for a left bar.
        readonly property bool atBottom: Metrics.barEdge === "bottom"
        readonly property bool onLeft: Metrics.barEdge === "left"
        // Slide-in offset, from the bar's side.
        readonly property real slide: Theme.space.md * (atBottom || Metrics.barEdge === "right" ? 1 : -1)
        property var grab: null
        readonly property bool wantsGrab: center.open && visible && (!leave.closeOnLeave || !leave.hoverSeen)

        function leaveRects() {
            const p = {
                x: window.onLeft ? window.margins.left + glass.shadowExtent : window.screen.width - window.margins.right - window.implicitWidth + glass.shadowExtent,
                y: window.atBottom ? window.screen.height - window.margins.bottom - window.implicitHeight + glass.shadowExtent : window.margins.top + glass.shadowExtent,
                width: glass.width,
                height: glass.height
            };
            const a = center.anchor && center.anchor.bar && center.anchor.item ? center.anchor.bar.menuHost.screenRect(center.anchor.item, 0, 0, center.anchor.item.width, center.anchor.item.height) : null;
            return leave.panelRects(p, a, Metrics.barEdge);
        }

        screen: Quickshell.screens.find(s => s.name === ShellState.notificationCenterScreen) || Quickshell.screens[0]
        visible: center.ownWindow && (center.open || glass.opacity > 0)
        color: "transparent"
        WlrLayershell.namespace: RunMode.layerNamespace("notificationcenter")
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: center.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        // Input only on the glass: the window's shadow margin reaches over the
        // bar, and would otherwise take its hover (LeaveWatch).
        mask: Region {
            item: glass
        }
        anchors.top: !atBottom
        anchors.bottom: atBottom
        anchors.right: !onLeft
        anchors.left: onLeft
        margins.top: atBottom ? 0 : Metrics.panelInset("top") - glass.shadowExtent
        margins.bottom: atBottom ? Metrics.panelInset("bottom") - glass.shadowExtent : 0
        margins.right: onLeft ? 0 : Metrics.panelInset("right") - glass.shadowExtent
        margins.left: onLeft ? Metrics.panelInset("left") - glass.shadowExtent : 0
        implicitWidth: Theme.layout.controlCenterWidth + glass.shadowExtent * 2
        implicitHeight: Math.min(screen.height * 0.8, content.implicitHeight) + glass.shadowExtent * 2

        onWantsGrabChanged: Qt.callLater(updateGrab)

        function updateGrab() {
            if (wantsGrab && !grab)
                grab = Compositor.createFocusGrab([window].concat(ShellState.barWindows), () => {
                    grab = null;
                    PopupGroup.noteDismissed("notificationCenter");
                    center.close();
                });
            else if (!wantsGrab && grab) {
                grab.release();
                grab = null;
            }
        }

        GlassSurface {
            id: glass

            material: Theme.materials.notifications
            x: shadowExtent + (center.open || !Metrics.barVertical ? 0 : window.slide)
            y: shadowExtent + (center.open || Metrics.barVertical ? 0 : window.slide)
            width: Theme.layout.controlCenterWidth
            height: window.height - shadowExtent * 2
            opacity: center.open && center.ownWindow ? 1 : 0

            HoverHandler {
                id: panelHover
            }

            Behavior on opacity {
                BNumberAnimation {}
            }

            Behavior on y {
                BNumberAnimation {
                    curve: "decelerate"
                }
            }

            Behavior on x {
                BNumberAnimation {
                    curve: "decelerate"
                }
            }

            NotificationCenterContent {
                id: content

                width: parent.width
                maxHeight: window.screen.height * 0.8
            }
        }
    }
}
