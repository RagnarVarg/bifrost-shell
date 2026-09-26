pragma Singleton

import QtQuick
import Quickshell
import qs.Compositor
import qs.Core
import qs.Components.Popup

// Transient UI state shared by shell modules: which panel is open on which
// screen, and the current OSD. Not persisted (that is Config's job).
Singleton {
    id: state

    property bool overviewOpen: false
    function openOverview() {
        if (locked || !Compositor.supports("windowList")) return;
        closePanels();
        overviewOpen=true;
    }
    function toggleOverview() { if (overviewOpen) overviewOpen=false; else openOverview(); }
    property bool launcherOpen: false
    property string launcherScreen: ""
    property string launcherQuery: ""     // initial query for the next open
    property bool controlCenterOpen: false
    property string controlCenterScreen: ""
    property string controlCenterDetail: ""   // "" | "bluetooth" | "wifi" | "output" | "input"
    // The bar button that opened it ({ item, bar }), for hover-leave closing;
    // null when opened from IPC or a keybind.
    property var controlCenterAnchor: null
    property bool controlCenterByHover: false
    property bool notificationCenterOpen: false
    property string notificationCenterScreen: ""
    property var notificationCenterAnchor: null
    property bool powerMenuOpen: false
    property string powerMenuScreen: ""
    property bool locked: false
    onLockedChanged: if (locked) overviewOpen=false

    // Bar windows, so panels can include them in their focus grab (a click on
    // the bar button then toggles the panel instead of counting as "outside").
    property var barWindows: []
    property var dockWindows: []
    function registerDock(w) { dockWindows = dockWindows.concat([w]); }
    function unregisterDock(w) { dockWindows = dockWindows.filter(x => x !== w); }

    function registerBar(w) {
        barWindows = barWindows.concat([w]);
    }

    function unregisterBar(w) {
        barWindows = barWindows.filter(x => x !== w);
    }

    // Asks the bar on `screen` to toggle a status menu (IPC/keybinds):
    // "network" | "vpn" | "bluetooth" | "audio".
    signal statusMenuRequested(string screen, string menu)

    function anyPanelOpen(screen: string): bool {
        return overviewOpen || launcherOpen || powerMenuOpen || (controlCenterOpen && controlCenterScreen === screen) || (notificationCenterOpen && notificationCenterScreen === screen);
    }

    property string osdKind: ""       // "volume" | "brightness" | "mic" | "media"
    property string osdAction: ""     // media: "toggle" | "next" | "previous" | "stop"
    property real osdValue: 0
    property bool osdMuted: false
    property bool osdVisible: false

    function focusedScreen(): string {
        return Compositor.focusedMonitor ? Compositor.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
    }

    function openLauncher(screen: string) {
        const scr = screen || focusedScreen();
        if (Placement.placeFor("launcher", Config.values.launcher.placement, "center", scr) === "bar") {
            controlCenterOpen = false;
            notificationCenterOpen = false;
            powerMenuOpen = false;
        } else {
            closePanels();
        }
        launcherScreen = scr;
        launcherOpen = true;
    }

    onLauncherOpenChanged: if (!launcherOpen)
        launcherQuery = ""


    function toggleLauncher(screen: string) {
        if (launcherOpen)
            launcherOpen = false;
        else
            openLauncher(screen);
    }

    // Opening a bar menu closes panels; opening a panel closes bar menus.
    Connections {
        target: PopupGroup

        function onOpened(popup) {
            state.overviewOpen=false;
            // Panels that are themselves a bar menu (Placement bar hosts)
            // stay open when their own menu opens.
            if (popup.panel !== "launcher")
                state.launcherOpen = false;
            if (popup.panel !== "controlCenter")
                state.controlCenterOpen = false;
            if (popup.panel !== "notificationCenter")
                state.notificationCenterOpen = false;
            state.powerMenuOpen = false;
        }
    }

    function closePanels() {
        overviewOpen=false;
        PopupGroup.closeAll();
        launcherOpen = false;
        controlCenterOpen = false;
        notificationCenterOpen = false;
        powerMenuOpen = false;
    }

    function toggleNotificationCenter(screen: string, anchor: var) {
        if (notificationCenterOpen) {
            notificationCenterOpen = false;
            return;
        }
        if (PopupGroup.justDismissed("notificationCenter"))
            return;
        openNotificationCenter(screen, anchor);
    }

    function openNotificationCenter(screen: string, anchor: var) {
        if (notificationCenterOpen)
            return;
        const scr = screen || focusedScreen();
        if (Placement.barHost("notificationCenter", scr)) {
            launcherOpen = false;
            controlCenterOpen = false;
            powerMenuOpen = false;
        } else {
            closePanels();
        }
        notificationCenterScreen = scr;
        notificationCenterAnchor = anchor || null;
        notificationCenterOpen = true;
    }

    function togglePowerMenu(screen: string) {
        const open = !powerMenuOpen;
        closePanels();
        powerMenuScreen = screen || focusedScreen();
        powerMenuOpen = open;
    }

    // `anchor` ({ item, bar }): the bar button, when opened from the bar.
    function toggleControlCenter(screen: string, anchor: var) {
        if (controlCenterOpen) {
            controlCenterOpen = false;
            return;
        }
        if (PopupGroup.justDismissed("controlCenter"))
            return;
        openControlCenter(screen, anchor, false);
    }

    // As a bar menu (Placement bar host) it closes the other menus itself.
    function openControlCenter(screen: string, anchor: var, byHover: bool) {
        if (controlCenterOpen)
            return;
        const scr = screen || focusedScreen();
        if (Placement.controlCenter === "bar" && Placement.barHost("controlCenter", scr)) {
            launcherOpen = false;
            notificationCenterOpen = false;
            powerMenuOpen = false;
        } else {
            closePanels();
        }
        controlCenterScreen = scr;
        controlCenterAnchor = anchor || null;
        controlCenterByHover = byHover;
        controlCenterOpen = true;
    }

    function showOsd(kind: string, value: real, muted: bool) {
        if (!Config.values.osd.enabled)
            return;
        osdKind = kind;
        osdValue = value;
        osdMuted = muted;
        osdVisible = true;
        osdTimer.restart();
    }

    // Feedback for a media key: the action and the (live) track. Callers
    // check that there is a player to act on.
    function showMediaOsd(action: string) {
        if (!Config.values.osd.enabled || !Config.values.osd.media)
            return;
        osdKind = "media";
        osdAction = action;
        osdVisible = true;
        osdTimer.restart();
    }

    Timer {
        id: osdTimer

        interval: Config.values.osd.timeoutMs
        onTriggered: state.osdVisible = false
    }
}
