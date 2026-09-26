import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Keeps the login screen's copy of your look current: when a setting it shows
// changes (look, glass, wallpaper, clock, your picture, displays, keyboard),
// runs `bifrostctl greeter sync` – only once the login screen is installed
// (its cache exists) and greeter.sync is on. Session shell only.
Scope {
    id: sync

    readonly property bool enabled: RunMode.isProduction && Config.values.greeter && Config.values.greeter.sync !== false
    readonly property var prefixes: ["appearance.", "materials.", "motion.", "clock.", "lock.", "wallpaper.", "greeter.", "displays.", "input."]
    property bool installed: false

    function run() {
        Ctl.run(["greeter", "sync", "--json"], (ok, out) => {
            if (!ok)
                console.warn("[bifrost] login screen copy failed:", out);
            else
                console.info("[bifrost] login screen copy updated");
        }, sync);
    }

    Component.onCompleted: Exec.run(["test", "-w", Platform.env("BIFROST_GREETER_CACHE") || "/var/cache/bifrost-greeter"], code => {
        sync.installed = code === 0;
        if (sync.installed && sync.enabled)
            later.restart();
    }, 3000)

    Connections {
        target: Config
        enabled: sync.enabled && sync.installed

        function onSettingChanged(key, value) {
            if (sync.prefixes.some(p => key.startsWith(p)))
                later.restart();
        }
    }

    Timer {
        id: later

        interval: 3000
        onTriggered: sync.run()
    }
}
