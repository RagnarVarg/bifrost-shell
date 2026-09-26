import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.Popup
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar
import qs.Services
import qs.Shared

// Control center: system status, network, Bluetooth, VPN, power profile,
// volume, microphone, brightness, media (ControlCenterContent). Where it opens
// is controlCenter.placement (Placement): grown out of the dock
// (Dock/DockPanelHost, which then also closes it), as the bar button's menu
// (ControlCenterWidget, "Top panel"), or – when the bar has no control center
// button on that screen – in its own window under the bar's end (below).
// Opened from the bar button it closes like a bar menu when the pointer leaves
// panel and button (LeaveWatch); a click outside closes it while that can't
// (from IPC, or bar.menus.closeOnLeave off).
Scope {
    id: cc

    readonly property var cfg: Config.values.controlCenter
    readonly property var bar: Config.values.bar
    readonly property bool open: ShellState.controlCenterOpen
    readonly property string detail: ShellState.controlCenterDetail
    readonly property var anchor: ShellState.controlCenterAnchor
    readonly property bool anchorHovered: anchor !== null && anchor.item !== null && anchor.item.hovered === true
    readonly property bool onDock: Placement.controlCenter === "dock"
    readonly property bool inBar: Placement.controlCenter === "bar" && Placement.barHost("controlCenter", ShellState.controlCenterScreen) !== null
    readonly property bool ownWindow: !onDock && !inBar

    function close() {
        ShellState.controlCenterOpen = false;
    }

    function placeOnDock() {
        if (open && onDock)
            Placement.showOnDock({
                id: "controlCenter",
                screen: ShellState.controlCenterScreen,
                component: dockContent,
                close: () => cc.close()
            });
        else
            Placement.hideFromDock("controlCenter");
    }

    // Moving it while open (setting changed, dock gone) closes it.
    onOnDockChanged: close()

    onOpenChanged: {
        placeOnDock();
        if (open) {
            leave.reset();
            SystemStats.retain();
            GpuStats.retain();
            Vpn.retain();
            Power.refresh();
        } else {
            ShellState.controlCenterDetail = "";
            ShellState.controlCenterAnchor = null;
            ShellState.controlCenterByHover = false;
            SystemStats.release();
            GpuStats.release();
            Vpn.release();
        }
    }

    Component {
        id: dockContent

        ControlCenterContent {}
    }

    LeaveWatch {
        id: leave

        active: cc.open && cc.ownWindow
        pointerInside: panelHover.hovered || cc.anchorHovered
        screenName: window.screen ? window.screen.name : ""
        rects: () => window.leaveRects()
        onLeft: cc.close()
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
        readonly property bool wantsGrab: cc.open && visible && (!leave.closeOnLeave || !leave.hoverSeen)

        // Monitor-local rects that count as "inside": the panel, its button,
        // and the gap between them.
        function leaveRects() {
            const p = {
                x: window.onLeft ? window.margins.left + glass.shadowExtent : window.screen.width - window.margins.right - window.implicitWidth + glass.shadowExtent,
                y: window.atBottom ? window.screen.height - window.margins.bottom - window.implicitHeight + glass.shadowExtent : window.margins.top + glass.shadowExtent,
                width: glass.width,
                height: glass.height
            };
            const a = cc.anchor && cc.anchor.bar && cc.anchor.item ? cc.anchor.bar.menuHost.screenRect(cc.anchor.item, 0, 0, cc.anchor.item.width, cc.anchor.item.height) : null;
            return leave.panelRects(p, a, Metrics.barEdge);
        }

        function updateGrab() {
            if (wantsGrab && !grab && cc.open)
                grab = Compositor.createFocusGrab([window], () => {
                    grab = null;
                    PopupGroup.noteDismissed("controlCenter");
                    cc.close();
                });
            else if (!wantsGrab && grab) {
                grab.release();
                grab = null;
            }
        }

        screen: Quickshell.screens.find(s => s.name === ShellState.controlCenterScreen) || Quickshell.screens[0]
        visible: cc.ownWindow && (cc.open || glass.opacity > 0)
        color: "transparent"
        WlrLayershell.namespace: RunMode.layerNamespace("controlcenter")
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: cc.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
        implicitHeight: content.implicitHeight + glass.shadowExtent * 2

        // Deferred: opening flips hoverSeen right after `open`.
        onWantsGrabChanged: Qt.callLater(updateGrab)

        GlassSurface {
            id: glass

            material: Theme.materials.controlCenter
            x: shadowExtent + (cc.open || !Metrics.barVertical ? 0 : window.slide)
            y: shadowExtent + (cc.open || Metrics.barVertical ? 0 : window.slide)
            width: Theme.layout.controlCenterWidth
            height: content.implicitHeight
            opacity: cc.open && cc.ownWindow ? 1 : 0

            Behavior on opacity {
                BNumberAnimation {}
            }

            HoverHandler {
                id: panelHover
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

            ControlCenterContent {
                id: content

                width: parent.width
                focus: cc.open
            }
        }
    }
}
