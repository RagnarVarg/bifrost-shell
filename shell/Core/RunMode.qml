pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Which session-wide resources this Bifrost instance may own.
//   overlay    – runs next to the production shell (DMS); no singleton services
//   nested     – inside a nested Hyprland with its own D-Bus; owns everything
//   production – the real session shell
Singleton {
    id: root

    readonly property var modes: ["overlay", "nested", "production"]
    readonly property string requested: Platform.env("BIFROST_RUN_MODE") || "overlay"
    readonly property string mode: modes.indexOf(requested) >= 0 ? requested : "overlay"

    readonly property bool isOverlay: mode === "overlay"
    readonly property bool isNested: mode === "nested"
    readonly property bool isProduction: mode === "production"

    readonly property bool ownsNotifications: !isOverlay
    readonly property bool ownsPolkit: !isOverlay
    readonly property bool ownsSessionLock: !isOverlay
    readonly property bool ownsWallpaper: !isOverlay
    readonly property bool reservesScreenSpace: !isOverlay
    readonly property bool appliesHyprlandSettings: isProduction

    readonly property string layerPrefix: "bifrost:"

    function layerNamespace(name: string): string {
        return layerPrefix + name;
    }

    Component.onCompleted: {
        if (requested !== mode)
            console.warn("[bifrost] unknown BIFROST_RUN_MODE '" + requested + "', using overlay");
    }
}
