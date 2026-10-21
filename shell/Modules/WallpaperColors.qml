import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Colours from the wallpaper (appearance.colorSource = "wallpaper"): runs
// `bifrostctl wallpaper-colors generate` at start, when the setting is turned
// on and when the wallpaper changes. bifrostctl writes (or, without matugen,
// removes) themes/bifrost-wallpaper.json; Theme watches that file in every
// Bifrost process, so the shell and Settings follow without a restart.
Scope {
    id: colors

    readonly property bool enabled: (Config.values.appearance || {}).colorSource === "wallpaper"
    property bool running: false
    property bool again: false

    function generate() {
        if (running) {
            again = true;
            return;
        }
        running = true;
        Ctl.run(["wallpaper-colors", "generate", "--json"], (ok, out, data) => {
            running = false;
            if (!ok)
                console.warn("[bifrost] wallpaper colours unavailable, using the theme's:", (data && data.message) || out);
            else if (data && data.changed)
                console.info("[bifrost] wallpaper colours generated");
            if (again) {
                again = false;
                generate();
            }
        }, colors, 60000);
    }

    Connections {
        target: Config

        function onSettingChanged(key, value) {
            if (key === "appearance.colorSource" || (colors.enabled && key === "wallpaper.path"))
                later.restart();
        }
    }

    // Coalesces a burst of changes (browsing wallpapers) into one run.
    Timer {
        id: later

        interval: 300
        onTriggered: if (colors.enabled) colors.generate()
    }

    Component.onCompleted: if (enabled) later.restart()
}
