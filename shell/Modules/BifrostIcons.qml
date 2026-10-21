import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Bifrost's own icons (appearance.icons.bifrost): runs `bifrostctl icons
// generate` at start and whenever what they are drawn from changes — the
// palette (theme, accent, colours from the wallpaper) or the inherited theme.
// bifrostctl only redraws when the result differs, into the slot not in use;
// IconTheme then switches to that slot and SystemAppearance hands the new
// name to GTK, Qt and gsettings (bifrostctl appearance apply).
Scope {
    id: icons

    readonly property bool enabled: (((Config.values.appearance || {}).icons) || {}).bifrost === true
    property string drawnFrom: ""
    property bool running: false
    property bool again: false

    function generate() {
        if (running) {
            again = true;
            return;
        }
        running = true;
        Ctl.run(["icons", "generate", "--json"], (ok, out, data) => {
            running = false;
            if (!ok)
                console.warn("[bifrost] Bifrost icons:", out);
            else if (data && data.changed) {
                console.info("[bifrost] Bifrost icons drawn:", data.theme, "(" + data.icons + " icons)");
                IconTheme.refresh();
            }
            if (again) {
                again = false;
                generate();
            }
        }, icons, 60000);
    }

    // What the drawing depends on; a change (in either mode's colours) redraws.
    function source(): string {
        const p = Theme.palette;
        return [Theme.themeId, Theme.fromWallpaper, p.accent, (p.aurora || []).join(), JSON.stringify(Config.values.appearance.accent || {}),
                JSON.stringify(Config.values.appearance.icons || {})].join("|");
    }

    Connections {
        target: Theme
        enabled: icons.enabled

        function onRevisionChanged() {
            const s = icons.source();
            if (s !== icons.drawnFrom) {
                icons.drawnFrom = s;
                later.restart();
            }
        }
    }

    onEnabledChanged: if (enabled) later.restart()

    Timer {
        id: later

        interval: 500
        onTriggered: if (icons.enabled) icons.generate()
    }

    Component.onCompleted: if (enabled) later.restart()
}
