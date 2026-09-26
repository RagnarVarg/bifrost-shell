pragma Singleton

import QtQuick
import Quickshell
import qs.Core

// Where a panel opens (controlCenter.placement, launcher.placement):
//   bar    – grown out of the bar ("Top panel") as a bar menu under its
//            button: one glass with the bar (MenuHost). A widget that hosts
//            the panel that way registers as a bar host for its screen;
//            without one the panel opens in its own window at the bar
//   dock   – grown out of the dock (Dock/DockPanelHost), one glass with it
//   center – on its own in the middle of the screen
// A dock placement falls back when the dock is off or has nothing on it.
// The dock shows one panel at a time: `dockPanel`
//   { id, screen, component, close() }
Singleton {
    id: placement

    property int dockEntries: 0             // set by the dock
    readonly property bool dockAvailable: Config.values.dock.enabled === true && dockEntries > 0

    function resolve(requested: string, fallback: string): string {
        if (requested === "dock" && !dockAvailable)
            return fallback;
        return requested || fallback;
    }

    readonly property string controlCenter: resolve(Config.values.controlCenter.placement, "bar")
    // Some panel opens on the dock (its window then keeps room for it).
    readonly property bool dockHostsPanels: controlCenter === "dock" || resolve(Config.values.launcher.placement, "center") === "dock"

    // Where `panel` opens on `screen`: like resolve(), and a bar placement
    // needs a bar host there (the panel's button on that screen's bar).
    function placeFor(panel: string, requested: string, fallback: string, screen: string): string {
        const r = resolve(requested, fallback);
        if (r === "bar" && fallback !== "bar" && !barHost(panel, screen))
            return fallback;
        return r;
    }

    // Bar hosts: "<panel>@<screen>" -> object with open(byHover), close().
    property var barHosts: ({})

    function registerBarHost(panel: string, screen: string, host) {
        const m = Object.assign({}, barHosts);
        m[panel + "@" + screen] = host;
        barHosts = m;
    }

    function unregisterBarHost(panel: string, screen: string, host) {
        if (barHosts[panel + "@" + screen] !== host)
            return;
        const m = Object.assign({}, barHosts);
        delete m[panel + "@" + screen];
        barHosts = m;
    }

    function barHost(panel: string, screen: string): var {
        return barHosts[panel + "@" + screen] || null;
    }

    property var dockPanel: null

    // Dock panel hosts, for IPC (`dock status`, hover tests).
    property var dockHosts: []

    function registerDockHost(h) {
        dockHosts = dockHosts.concat([h]);
    }

    function unregisterDockHost(h) {
        dockHosts = dockHosts.filter(x => x !== h);
    }

    function showOnDock(panel) {
        const prev = dockPanel;
        dockPanel = panel;
        if (prev && prev.id !== panel.id)
            prev.close();
    }

    function hideFromDock(id: string) {
        if (dockPanel && dockPanel.id === id)
            dockPanel = null;
    }
}
