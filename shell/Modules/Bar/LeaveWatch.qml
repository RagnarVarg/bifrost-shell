import QtQuick
import qs.Compositor
import qs.Core

// Closes a bar menu or a panel opened from the bar once the pointer has left
// it and its anchor for bar.menus.closeDelayMs. Shared by MenuHost and the
// control center.
//   - armed once the pointer has been inside (`hoverSeen`), so something
//     opened from IPC or a keybind stays open; call reset() on open
//   - Wayland reports spurious leaves (e.g. while a surface maps or resizes),
//     so the compositor is asked where the pointer is before closing, and
//     asked again while hover says outside but the pointer is still there
//   - `rects` must not cover other bar widgets: while the pointer is on one,
//     the compositor check would keep this open (see panelRects). Panels in
//     their own window also need an input mask on their glass, or their
//     transparent margin over the bar takes the bar's hover (the next widget
//     then never sees the pointer and can't open its menu).
Timer {
    id: watch

    property bool active: false             // something is open
    property bool pointerInside: false
    property bool closeOnLeave: Config.values.bar.menus.closeOnLeave
    property string screenName: ""
    property var rects: () => []            // monitor-local rects that count as inside
    property bool hoverSeen: false
    property int generation: 0

    signal left

    // Rects for a panel in its own window, opened from a bar button: the
    // panel, the button, and only the gap between them. A gap as wide as the
    // panel would reach over the bar's other widgets, so moving on to one of
    // them would count as inside. `edge` is the bar's edge (Metrics.barEdge).
    function panelRects(panel, anchor, edge: string): var {
        if (!anchor)
            return [panel];
        const p = panel, a = anchor;
        if (edge === "left" || edge === "right") {
            const l = edge === "left" ? a.x + a.width : p.x + p.width;
            const r = edge === "left" ? p.x : a.x;
            const t = Math.min(a.y, p.y);
            return [p, a, { x: l, y: t, width: Math.max(0, r - l), height: Math.max(a.y + a.height, p.y + p.height) - t }];
        }
        const top = edge === "bottom" ? p.y + p.height : a.y + a.height;
        const bottom = edge === "bottom" ? a.y : p.y;
        const left = Math.min(a.x, p.x);
        const right = Math.max(a.x + a.width, p.x + p.width);
        return [p, a, { x: left, y: top, width: right - left, height: Math.max(0, bottom - top) }];
    }

    function reset() {
        generation++;
        // `pointerInside` may depend on hoverSeen (MenuHost, centred menus):
        // judge it for the new menu, not with the previous one's.
        hoverSeen = false;
        hoverSeen = pointerInside;
        stop();
    }

    interval: Config.values.bar.menus.closeDelayMs
    onActiveChanged: if (!active)
        stop()
    onPointerInsideChanged: {
        if (!active)
            return;
        if (pointerInside) {
            hoverSeen = true;
            stop();
        } else if (hoverSeen && closeOnLeave) {
            restart();
        }
    }
    onTriggered: {
        if (!active || pointerInside)
            return;
        const gen = generation;
        Compositor.pointerInAny(screenName, rects(), inside => {
            if (gen !== watch.generation || !watch.active || watch.pointerInside)
                return;
            if (inside === true)
                watch.restart();
            else
                watch.left();
        });
    }
}
