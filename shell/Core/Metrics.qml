pragma Singleton

import QtQuick
import Quickshell

// Effective sizes of Bifrost's panels: the user's settings (bar.height,
// dock.iconSize …) times the density profile (Theme.density). Modules read
// sizes from here, never straight from Config, so density and later frame
// layouts change every panel the same way.
Singleton {
    id: root

    readonly property var density: Theme.density
    readonly property var bar: Config.values.bar || ({})
    readonly property var dock: Config.values.dock || ({})

    function panel(v: real): real {
        return Math.round(v * density.panel);
    }

    function gap(v: real): real {
        return Math.round(v * density.space);
    }

    function icon(v: real): real {
        return Math.round(v * density.icon);
    }

    // Frame: the bar is one side of a glass frame around the screen, flush
    // with the edge; the other sides are frameThickness wide.
    readonly property bool frame: bar.layout === "frame"
    readonly property real frameThickness: frame ? panel(((bar.frame || {}).thickness) || 6) : 0
    readonly property real barHeight: panel(bar.height || 0)
    readonly property real barMargin: frame || bar.style === "attached" ? 0 : gap(bar.margin || 0)
    readonly property real barSpacing: gap(bar.spacing || 0)
    // Screen space the bar occupies from its edge (glass plus margins).
    readonly property real barSpace: bar.enabled ? barHeight + barMargin * 2 : 0
    // The screen edge the bar is on, and whether it is a side bar.
    readonly property string barEdge: ["top", "bottom", "left", "right"].indexOf(bar.position) >= 0 ? bar.position : "top"
    readonly property bool barVertical: barEdge === "left" || barEdge === "right"

    // Space Bifrost's bar or frame takes from one screen edge; panels that
    // sit against that edge keep this far away from it.
    function edgeSpace(edge: string): real {
        if (!bar.enabled)
            return 0;
        return edge === barEdge ? barSpace : frameThickness;
    }

    // Distance from a screen edge for a panel in the corner at the bar's end
    // (control center, notification center): the bar's space on the bar's
    // edge, a small gap (plus the frame) on the edges beside it.
    function panelInset(edge: string): real {
        return edge === barEdge ? edgeSpace(edge) : barMargin + edgeSpace(edge) + Theme.space.xs;
    }

    readonly property real dockIconSize: icon(dock.iconSize || 0)
    readonly property real dockMargin: gap(dock.margin || 0)
    readonly property real dockPadding: Theme.space.sm
    readonly property real dockExtraPadding: gap(dock.extraPadding || 0)
    readonly property real dockHeight: dockIconSize + dockPadding * 4 + dockExtraPadding * 2

    readonly property real launcherIconSize: icon((Config.values.launcher || {}).iconSize || 48)
}
