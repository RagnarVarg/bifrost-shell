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
    readonly property var cfg: Config.values.wallpaper
    readonly property string source: cfg.path ? "file://" + Platform.expandHome(cfg.path) : ""
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
