pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import Quickshell.Services.SystemTray

// StatusNotifier items (Quickshell.Services.SystemTray). Several hosts may
// run at once, so this works next to DMS in overlay mode.
Singleton {
    readonly property var items: SystemTray.items.values

    // Normalised read helpers so widgets don't depend on the item API.
    function iconOf(item) {
        // Themed tray icons come as image://icon/<name>: resolve them from
        // Bifrost's icon theme like every other app icon.
        return item ? Platform.iconPath(item.icon, "") : "";
    }

    function titleOf(item) {
        return item ? (item.tooltipTitle || item.title || item.id) : "";
    }

    function hasMenu(item) {
        return item ? item.hasMenu : false;
    }

    function menuOnly(item) {
        return item ? item.onlyMenu : false;
    }

    function activate(item) {
        if (item)
            item.activate();
    }

    function secondaryActivate(item) {
        if (item)
            item.secondaryActivate();
    }

    function scroll(item, delta, horizontal) {
        if (item)
            item.scroll(delta, horizontal);
    }

    function menuOf(item) {
        return item && item.hasMenu ? item.menu : null;
    }
}
