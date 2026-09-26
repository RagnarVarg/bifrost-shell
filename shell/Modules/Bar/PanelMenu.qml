import QtQuick
import qs.Core
import qs.Modules

// A shell panel (control center, launcher, notification center) shown as its
// bar button's menu, grown out of the bar like every other bar menu (MenuHost).
// The panel's open state lives in ShellState (IPC and keybinds set it): the
// menu follows `panelOpen` and reports its own opening and closing (hover,
// leave, outside click, another menu) back through the two signals. While
// `hosting`, it registers as the panel's bar host for its screen (Placement),
// which keeps the panel's own window closed there.
//   PanelMenu {
//       panel: "notificationCenter"; bar: widget.bar; anchorItem: button
//       hosting: …; panelOpen: ShellState.xOpen && ShellState.xScreen === screenName
//       onOpenRequested: byHover => ShellState.openX(screenName, …)
//       onCloseRequested: ShellState.xOpen = false
//       Content {}
//   }
BarMenu {
    id: menu

    required property string panel
    property bool hosting: true
    property bool panelOpen: false
    readonly property string screenName: bar ? bar.modelData.name : ""
    // The screen this menu is registered as bar host for ("" = none).
    property string hostScreen: ""

    signal openRequested(bool byHover)
    signal closeRequested

    padding: 0
    openOnHover: hosting && Config.values.bar.menus.openOnHover

    function syncHost() {
        const want = hosting && screenName !== "" ? screenName : "";
        if (want === hostScreen)
            return;
        if (hostScreen !== "")
            Placement.unregisterBarHost(panel, hostScreen, menu);
        hostScreen = want;
        if (want !== "")
            Placement.registerBarHost(panel, want, menu);
    }

    onHostingChanged: syncHost()
    onScreenNameChanged: syncHost()
    Component.onCompleted: syncHost()
    Component.onDestruction: if (hostScreen !== "")
        Placement.unregisterBarHost(panel, hostScreen, menu)

    onPanelOpenChanged: {
        if (!hosting)
            return;
        if (panelOpen)
            open();
        else
            close();
    }

    onIsOpenChanged: {
        if (isOpen && !panelOpen)
            openRequested(openedByHover);
        else if (!isOpen && panelOpen)
            closeRequested();
    }
}
