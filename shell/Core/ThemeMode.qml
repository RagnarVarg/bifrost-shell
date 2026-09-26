pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import "Sun.js" as Sun

// Decides whether Bifrost is light or dark (appearance.mode):
//   dark / light – fixed
//   system       – follows the system preference (org.gnome.desktop.interface
//                  color-scheme, which the XDG portal publishes to apps)
//   auto         – light between sunrise and sunset at the user's location,
//                  dark otherwise; recomputed at every sunrise/sunset. The
//                  location is appearance.location.* if set, else the
//                  coordinates of the system time zone (zone1970.tab), so it
//                  works offline. Without a location it falls back to system.
//
// Pushing the result to apps (GTK, Qt, portal) is done by the shell's
// SystemAppearance module; Settings only reads this.
Singleton {
    id: root

    readonly property var cfg: Config.values.appearance || ({})
    readonly property string mode: ["dark", "light", "system", "auto"].indexOf(cfg.mode) >= 0 ? cfg.mode : "dark"

    // "dark" | "light" | "" (unknown, e.g. no gsettings)
    property string systemVariant: ""
    property var zoneLocation: null     // { lat, lon, zone } from the time zone
    readonly property var manualLocation: {
        const l = cfg.location || {};
        return typeof l.latitude === "number" && typeof l.longitude === "number" ? { lat: l.latitude, lon: l.longitude, zone: "" } : null;
    }
    readonly property var location: manualLocation || zoneLocation
    readonly property string locationSource: manualLocation ? "manual" : zoneLocation ? "timezone" : ""

    property bool daylight: true
    property var sunrise: null
    property var sunset: null
    property var nextChange: null
    property string polar: ""

    readonly property bool autoAvailable: location !== null
    readonly property string variant: {
        if (mode === "light" || mode === "dark")
            return mode;
        if (mode === "auto" && autoAvailable)
            return daylight ? "light" : "dark";
        return systemVariant || "dark";
    }
    // What "auto" actually does right now (for Settings).
    readonly property string effectiveSource: mode === "auto" && !autoAvailable ? "system" : mode

    function recompute() {
        if (!location) {
            sunrise = sunset = nextChange = null;
            return;
        }
        const now = new Date();
        const t = Sun.times(now, location.lat, location.lon);
        sunrise = t.sunrise;
        sunset = t.sunset;
        polar = t.polar;
        daylight = Sun.isDaylight(now, location.lat, location.lon);
        nextChange = Sun.nextChange(now, location.lat, location.lon);
        if (nextChange) {
            // Fire a little after the event; the periodic check covers sleep.
            changeTimer.interval = Math.max(1000, Math.min(nextChange.getTime() - now.getTime() + 5000, 2147483000));
            changeTimer.restart();
        }
    }

    function parseScheme(text: string) {
        const s = text.replace(/['"\s]/g, "").replace(/^color-scheme:/, "");
        systemVariant = s === "prefer-dark" ? "dark" : s === "prefer-light" || s === "default" ? "light" : systemVariant;
    }

    onLocationChanged: recompute()

    Timer {
        id: changeTimer

        onTriggered: root.recompute()
    }

    // Catches suspend/resume and clock changes.
    Timer {
        interval: 10 * 60 * 1000
        running: root.mode === "auto"
        repeat: true
        onTriggered: root.recompute()
    }

    LineWatcher {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        onLine: text => root.parseScheme(text)
    }

    Component.onCompleted: {
        Exec.run(["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"], (code, out) => {
            if (code === 0)
                root.parseScheme(out);
        });
        const tz = Platform.env("TZ").replace(/^:/, "");
        Exec.run(["sh", "-c", "z=\"$0\"; [ -n \"$z\" ] || z=$(cat /etc/timezone 2>/dev/null || readlink /etc/localtime | sed 's|.*/zoneinfo/||'); for f in /usr/share/zoneinfo/zone1970.tab /usr/share/zoneinfo/zone.tab; do c=$(awk -v z=\"$z\" '$3==z {print $2; exit}' \"$f\" 2>/dev/null); [ -n \"$c\" ] && { echo \"$c $z\"; exit 0; }; done; exit 1", tz], (code, out) => {
            const parts = out.trim().split(" ");
            const p = code === 0 ? Sun.parseIso6709(parts[0]) : null;
            root.zoneLocation = p ? { lat: p.lat, lon: p.lon, zone: parts[1] } : null;
        });
        recompute();
    }
}
