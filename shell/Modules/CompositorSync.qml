import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Keeps the compositor in step with Bifrost's settings: keybindings, the look
// of ordinary windows, compositor blur and displays. Every change to a
// setting with scope "hyprland" (or one the generated file derives from, like
// the accent colour) regenerates ~/.config/bifrost/hypr/bifrost.lua and runs
// it in the live compositor (bifrostctl hypr apply; idempotent). The result,
// and whether the file is hooked into the compositor config (so it survives
// a restart), is published for Settings in $XDG_RUNTIME_DIR/bifrost/compositor.json.
Scope {
    id: sync

    readonly property bool enabled: RunMode.appliesHyprlandSettings
    readonly property var derivedKeys: ["appearance.accent", "appearance.theme", "appearance.mode", "appearance.radiusScale"]

    function affects(key: string): bool {
        const d = Schema.entries[key];
        return (d && d.scope === "hyprland") || derivedKeys.indexOf(key) >= 0;
    }

    function apply() {
        Ctl.run(["hypr", "apply", "--json"], (ok, out, data) => {
            const result = data || { ok: false, message: out };
            result.at = Date.now();
            if (!ok)
                console.error("[bifrost] compositor apply failed:", out);
            else
                console.info("[bifrost] compositor settings applied (hooked:", result.hooked + ")");
            status.write(JSON.stringify(result));
        }, sync);
    }

    Connections {
        target: Config
        enabled: sync.enabled

        function onSettingChanged(key, value) {
            if (sync.affects(key))
                applyLater.restart();
        }
    }

    // Border colours follow light/dark, which can change without a setting
    // (system preference, sunrise/sunset).
    Connections {
        target: Theme
        enabled: sync.enabled

        function onVariantChanged() {
            applyLater.restart();
        }
    }

    Timer {
        id: applyLater

        interval: 250
        onTriggered: sync.apply()
    }

    WatchedFile {
        id: status

        watch: false
        path: Paths.runtimeDir + "/compositor.json"
    }

    Component.onCompleted: {
        if (enabled)
            applyLater.restart();
    }
}
