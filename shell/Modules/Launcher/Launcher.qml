import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Components.Glass
import qs.Components.Motion
import qs.Modules

// App launcher (LauncherContent). Where it opens is launcher.placement
// (Placement):
//   dock   – grown out of the dock (Dock/DockPanelHost), the default
//   center – on its own in the middle of the screen (this window)
//   bar    – "Top panel": the bar's launcher button's menu (LauncherWidget)
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

        readonly property bool shown: launcher.open && launcher.where === "center"

        screen: Quickshell.screens.find(s => s.name === launcher.screenName) || Quickshell.screens[0]
        visible: shown || glass.opacity > 0
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
            height: content.implicitHeight
            anchors.centerIn: parent
            opacity: window.shown ? 1 : 0
            scale: window.shown ? 1 : 0.98

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

                anchors.fill: parent
                maxHeight: window.height - Metrics.edgeSpace("top") - Metrics.edgeSpace("bottom") - Theme.space.xxxl * 2
            }
        }
    }
}
