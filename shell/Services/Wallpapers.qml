pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Which wallpaper a screen shows, from the wallpaper settings: one place for
// the desktop (Modules/Wallpaper) and everything that pictures the desktop
// (the workspace preview), so they always agree. One image for all screens
// today; per-screen wallpapers only change sourceFor().
Singleton {
    id: root

    property var images: []
    property string scanError: ""
    property bool scanning: false
    property int consumers: 0
    readonly property string locations: JSON.stringify([cfg.directory || "", cfg.path || ""])

    function fileUrl(path: string): string {
        return path ? "file://" + Platform.expandHome(path).split("/").map(encodeURIComponent).join("/") : "";
    }

    function retain() { consumers++; refresh(); }
    function release() { consumers = Math.max(0, consumers - 1); }
    function apply(path: string): string { return Config.set("wallpaper.path", path); }

    function refresh() {
        if (scanning) return;
        scanning = true;
        const requested = locations;
        Exec.run(["python3", Paths.repoDir + "/tools/wallpapers.py", cfg.directory || "", cfg.path || ""], (code, out) => {
            scanning = false;
            if (requested !== locations) { refresh(); return; }
            if (code !== 0) {
                scanError = I18n.tr("Could not scan wallpaper folders");
                return;
            }
            try {
                const result = JSON.parse(out);
                if (JSON.stringify(images) !== JSON.stringify(result.images)) images = result.images;
                scanError = result.errors.join("\n");
            } catch (error) { scanError = String(error); }
        }, 10000, root);
    }

    onLocationsChanged: if (consumers > 0) refresh()

    Timer {
        interval: 3000
        repeat: true
        running: root.consumers > 0
        onTriggered: root.refresh()
    }

    readonly property var cfg: Config.values.wallpaper || ({})
    readonly property string source: fileUrl(cfg.path || "")
    // How the image fills the screen, as an Image.fillMode.
    readonly property int fillMode: ({
            fill: Image.PreserveAspectCrop,
            fit: Image.PreserveAspectFit,
            center: Image.Pad,
            tile: Image.Tile
        })[cfg.fillMode] ?? Image.PreserveAspectCrop

    function sourceFor(screenName: string): string {
        return source;
    }
}
