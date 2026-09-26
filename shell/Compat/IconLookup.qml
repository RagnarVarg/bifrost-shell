pragma Singleton

import QtQuick
import Quickshell

// The icon theme Bifrost resolves app icons from: a name → file map for the
// whole theme chain (built by bifrostctl icons index, loaded by
// Core/IconTheme). Empty until loaded; Platform.iconPath then falls back to
// Qt's own lookup (QS_ICON_THEME / system).
Singleton {
    property string theme: ""
    property var icons: ({})

    function lookup(name: string): string {
        const p = icons[name];
        return p ? "file://" + p : "";
    }
}
