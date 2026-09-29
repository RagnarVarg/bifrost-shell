import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Components.Glass
import qs.Components.Motion
import qs.Modules
import "../../Shared/GlassJoin.js" as GlassJoin

// App launcher (LauncherContent). Where it opens is launcher.placement
// (Placement):
//   dock   – grown out of the dock (Dock/DockPanelHost), the default
//   center – on its own in the middle of the screen (this window)
//   bar    – "Top panel": the bar's launcher button's menu (LauncherWidget)
//   top    – grown out of the middle of the top screen edge, wherever the
//            bar is (this window). In the frame layout the frame's glass
//            draws its shape (ShellState.launcherFrameAttachment).
// Without a dock, fall back to center. BarWindow hosts a joined menu when no button exists.
Scope {
    id: launcher

    readonly property string screenName: ShellState.launcherScreen
    readonly property string where: Placement.resolve(Config.values.launcher.placement, "center")
    readonly property bool open: ShellState.launcherOpen

    function close() {
        ShellState.launcherOpen = false;
    }

    function placeOnDock() {
        if (open && where === "dock")
            Placement.showOnDock({
                id: "launcher",
                screen: screenName,
                component: dockContent,
                exclusiveKeyboard: true,
                close: () => launcher.close()
            });
        else
            Placement.hideFromDock("launcher");
    }

    onOpenChanged: placeOnDock()
    // Moving it while open (setting changed, dock gone) closes it.
    onWhereChanged: close()

    Component {
        id: dockContent

        LauncherContent {}
    }

    PanelWindow {
        id: window

        readonly property bool shown: launcher.open && (launcher.where === "center" || launcher.where === "top")
        readonly property bool atTop: launcher.where === "top"
        // Joined to the frame: the frame's glass is the launcher's glass.
        readonly property bool joined: atTop && Metrics.frame
        readonly property real topEdge: Metrics.edgeSpace("top")
        // 0..1: how far the joined shape has grown out of the edge.
        property real reveal: shown ? 1 : 0

        Behavior on reveal {
            BNumberAnimation {
                curve: "decelerate"
            }
        }

        readonly property var frameAttachment: {
            if (!joined || reveal <= 0 || glass.height <= 0)
                return null;
            const r = { x: glass.x, y: topEdge, width: glass.width, height: glass.height };
            return GlassJoin.between({ x: 0, y: 0, width: width, height: topEdge }, r, "top", Theme.radius.lg, Theme.radius.lg, true);
        }
        onFrameAttachmentChanged: ShellState.launcherFrameAttachment = frameAttachment

        screen: Quickshell.screens.find(s => s.name === launcher.screenName) || Quickshell.screens[0]
        visible: shown || (joined ? reveal > 0 : glass.opacity > 0)
        color: "transparent"
        WlrLayershell.namespace: RunMode.layerNamespace("launcher")
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        // Click outside the glass closes.
        MouseArea {
            anchors.fill: parent
            enabled: window.shown
            onClicked: launcher.close()
        }

        GlassSurface {
            id: glass

            material: Theme.materials.launcher
            width: Math.min(window.width - Theme.space.xxxl * 2, content.implicitWidth)
            // Joined, the shape grows out of the edge; the content stays put and is clipped.
            height: window.joined ? Math.round(content.implicitHeight * window.reveal) : content.implicitHeight
            x: Math.round((window.width - width) / 2)
            y: window.atTop ? window.topEdge + (window.joined ? 0 : Theme.space.md) : Math.round((window.height - height) / 2)
            // Joined, the frame's glass is drawn instead.
            paintEnabled: !window.joined
            clip: window.joined
            opacity: window.joined ? 1 : window.shown ? 1 : 0
            scale: window.joined || window.shown ? 1 : 0.98

            Behavior on opacity {
                BNumberAnimation {}
            }

            Behavior on scale {
                BNumberAnimation {
                    curve: "decelerate"
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            LauncherContent {
                id: content
                active: window.shown

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: implicitHeight
                maxHeight: window.height - Metrics.edgeSpace("top") - Metrics.edgeSpace("bottom") - Theme.space.xxxl * 2
            }
        }
    }
}
