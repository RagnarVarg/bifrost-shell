import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Modules
import qs.Modules.Bar
import qs.Modules.Launcher

// Bifrost mark; opens the launcher on this bar's screen. With
// launcher.placement "bar" (Top panel) the launcher is this button's bar
// menu, grown out of the bar (MenuHost); the menu and ShellState.launcherOpen
// follow each other, so keybinds and IPC open the same menu. Otherwise the
// launcher opens where its placement says (Launcher).
BarWidget {
    id: widget

    readonly property string screenName: bar ? bar.modelData.name : ""
    readonly property bool hosts: Config.values.launcher.placement === "bar" && widget.bar !== null
    readonly property bool openHere: ShellState.launcherOpen && ShellState.launcherScreen === screenName

    implicitWidth: button.implicitWidth

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        selected: menu.isOpen || widget.openHere
        onClicked: {
            if (widget.hosts)
                menu.click();
            else
                ShellState.toggleLauncher(widget.screenName);
        }

        BIcon {
            source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
            size: Theme.icon.size.lg
            color: Theme.color.text
        }
    }

    PanelMenu {
        id: menu

        panel: "launcher"
        bar: widget.bar
        anchorItem: button
        hosting: widget.hosts
        panelOpen: widget.openHere
        openOnHover: false
        exclusiveKeyboard: true
        centerOnScreen: true
        onOpenRequested: ShellState.openLauncher(widget.screenName)
        onCloseRequested: ShellState.launcherOpen = false

        LauncherContent {
            active: menu.isOpen
            width: widget.bar ? Math.min(implicitWidth, widget.bar.modelData.width - Theme.space.xxxl * 2) : implicitWidth
            height: implicitHeight
            maxHeight: widget.bar ? widget.bar.modelData.height - Metrics.edgeSpace(Metrics.barEdge) - Metrics.edgeSpace("bottom") - Theme.space.xxxl : Theme.layout.launcherHeight
        }
    }
}
