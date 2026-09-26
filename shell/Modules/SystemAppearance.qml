import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Carries Bifrost's light/dark and icon theme over to the rest of the
// desktop (appearance.syncSystem): the XDG portal colour scheme (browsers,
// GTK4, Qt), the GTK theme's dark/light counterpart, GTK settings.ini,
// qt6ct/qt5ct (icon theme, Kvantum dark/light) and the system icon theme.
// The work is done by `bifrostctl appearance apply` (one implementation);
// what it could and couldn't do is published in
// $XDG_RUNTIME_DIR/bifrost/appearance.json for Settings.
// In "system" mode Bifrost follows the desktop instead, so nothing is pushed.
Scope {
    id: sync

    readonly property bool enabled: RunMode.isProduction && Config.values.appearance.syncSystem !== false && ThemeMode.mode !== "system"
    readonly property string variant: Theme.variant
    readonly property string icons: IconTheme.theme

    function apply() {
        const publish = extra => status.write(JSON.stringify(Object.assign({ variant: sync.variant, mode: ThemeMode.mode, iconTheme: sync.icons, synced: sync.enabled, at: Date.now() }, extra || {})));
        if (!enabled) {
            publish({});
            return;
        }
        Ctl.run(["appearance", "apply", "--variant", variant, "--json"], (ok, out, data) => {
            if (!ok)
                console.warn("[bifrost] system appearance:", out);
            else
                console.info("[bifrost] system appearance:", variant, data ? data.targets.map(t => t.target + "=" + t.status).join(" ") : "");
            publish({ targets: data ? data.targets : [] });
        }, sync);
    }

    onVariantChanged: applyLater.restart()
    onIconsChanged: applyLater.restart()
    onEnabledChanged: applyLater.restart()

    Timer {
        id: applyLater

        interval: 400
        onTriggered: sync.apply()
    }

    WatchedFile {
        id: status

        watch: false
        path: Paths.runtimeDir + "/appearance.json"
    }

    Component.onCompleted: applyLater.restart()
}
