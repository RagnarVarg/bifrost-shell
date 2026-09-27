import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Components.Motion
import "../../Shared/GlassJoin.js" as GlassJoin

// Hosts the bar's menus (BarMenu) inside the bar window, so a menu is drawn
// as part of the bar: the glass under the menu's anchor grows a rect toward
// the screen (GlassSurface.attachment) with concave corners where it meets
// the bar. One menu per bar; switching glides the shape to the new menu.
//
// Closing, shared by every bar menu:
//   - the pointer leaves the menu and its anchor (LeaveWatch)
//   - a click outside the bar window (compositor focus grab), Esc
// The focus grab keeps the pointer on the bar, so no leave arrives while it is
// held: it is only taken while hover-leave can't close the menu (turned off,
// or the pointer has not been inside yet); leaving closes before any outside
// click otherwise.
//   - another menu opens (PopupGroup, across bars)
// Fill the parent (the bar's content item); coordinates are content coords.
Item {
    id: host

    required property var bar           // BarWindow
    property Item band: null            // the bar band (the anchor's hover strip spans it)
    property var glasses: []            // glass surfaces a menu can grow from

    readonly property bool down: !bar.atBottom
    readonly property real fillet: Theme.radius.lg
    readonly property real menuRadius: Theme.radius.lg

    property var menu: null             // the open menu
    property Item hostGlass: null
    property rect anchorStrip: Qt.rect(0, 0, 0, 0)    // the anchor over the full band height
    readonly property alias hoverSeen: leave.hoverSeen
    property var grab: null

    // Shape of the menu area, animated. The bar window never changes size in
    // use: every resize shows one frame without the glass (Qt/Wayland), which
    // made the bar flicker on each menu open and close. So it keeps room for
    // the menus from the start (`standingRoom`; the input mask covers only the
    // glass and the open menu) and grows past it only for a taller menu.
    readonly property real targetHeight: menu ? menu.menuHeight : 0
    property real shapeHeight: targetHeight
    property real shapeX: 0
    property real shapeWidth: 0
    readonly property real standingRoom: bar ? Math.round((bar.vertical ? bar.modelData.width : bar.modelData.height) * 0.9) : 0
    property real room: standingRoom

    readonly property alias area: area
    readonly property alias menuLayer: menuLayer
    readonly property bool wantsKeyboard: menu !== null && menu.grabFocus
    readonly property bool wantsGrab: menu !== null && menu.grabFocus && (!menu.closeOnLeave || !hoverSeen)
    // A centred menu counts its anchor only once the pointer has been on it
    // (BarMenu.centerOnScreen); until then the focus grab closes it.
    readonly property bool pointerInside: area.containsMouse || (anchorHovered && !(menu.centerOnScreen && !hoverSeen))
    // Anchors expose `hovered` (BarButton, status and tray icons, the system
    // status group): their own MouseArea is the only reliable hover source
    // there, as Qt does not tell overlapping handlers when the pointer moves on.
    readonly property bool anchorHovered: menu !== null && menu.anchorItem !== null && menu.anchorItem.hovered === true

    Behavior on shapeHeight {
        BNumberAnimation {
            speed: "normal"
            curve: "emphasized"
        }
    }

    Behavior on shapeX {
        enabled: host.shapeHeight > 0

        BNumberAnimation {
            speed: "normal"
            curve: "emphasized"
        }
    }

    Behavior on shapeWidth {
        enabled: host.shapeHeight > 0

        BNumberAnimation {
            speed: "normal"
            curve: "emphasized"
        }
    }

    onTargetHeightChanged: if (targetHeight > room)
        room = targetHeight
    onShapeHeightChanged: if (shapeHeight === targetHeight)
        room = Math.max(standingRoom, targetHeight)
    onStandingRoomChanged: room = Math.max(standingRoom, targetHeight)

    function show(m) {
        if (menu === m)
            return;
        const prev = menu;
        menu = m;
        if (prev)
            prev.close();
        place(m);
        leave.reset();
        Qt.callLater(updateGrab);
        if (m.grabFocus)
            area.forceActiveFocus();
    }

    function hide(m) {
        if (menu !== m)
            return;
        menu = null;
        Qt.callLater(updateGrab);
    }

    function updateGrab() {
        if (wantsGrab && !grab) {
            grab = Compositor.createFocusGrab([bar], () => {
                host.grab = null;
                if (host.menu)
                    host.menu.close();
            });
        } else if (!wantsGrab && grab) {
            grab.release();
            grab = null;
        }
    }

    onWantsGrabChanged: Qt.callLater(updateGrab)

    // The glass under x: the one bar glass, or the island there (nearest).
    function glassAt(x) {
        const list = glasses.filter(g => g && g.visible && g.width > 0);
        let best = null, bestDist = Infinity;
        for (const g of list) {
            const dist = x < g.x ? g.x - x : x > g.x + g.width ? x - g.x - g.width : 0;
            if (dist < bestDist) {
                best = g;
                bestDist = dist;
            }
        }
        return best;
    }

    // Horizontal placement: centred under the anchor, inside the glass it
    // grows from, and flush with the glass edge when a concave corner would
    // not fit beside the glass's own rounded corner.
    function place(m) {
        if (!m || !m.anchorItem)
            return;
        const a = rectIn(m.anchorItem);
        // Centred: the middle of the band, which spans the monitor along the bar.
        const ax = m.centerOnScreen && band ? mapFromItem(band, band.width / 2, 0).x : a.x + a.width / 2;
        let g = glassAt(ax);
        // It joins a glass only if it grows from it, else it floats.
        if (m.centerOnScreen && g && (ax < g.x || ax > g.x + g.width))
            g = null;
        hostGlass = g;
        const top = band ? mapFromItem(band, 0, 0).y : 0;
        anchorStrip = Qt.rect(a.x, top, a.width, band ? band.height : height);
        const W = m.menuWidth;
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
        let x = clamp(ax - W / 2, 0, Math.max(0, width - W));
        if (g) {
            const r = Math.min(g.radius, g.height / 2);
            if (W <= g.width) {
                x = clamp(ax - W / 2, g.x, g.x + g.width - W);
                if (x - g.x < r + fillet)
                    x = g.x;
                else if (g.x + g.width - (x + W) < r + fillet)
                    x = g.x + g.width - W;
            } else {
                if (g.x - x < menuRadius + fillet)
                    x = g.x;
                else if (x + W - g.x - g.width < menuRadius + fillet)
                    x = g.x + g.width - W;
                x = clamp(x, 0, Math.max(0, width - W));
            }
        }
        m.targetX = x;
        shapeX = x;
        shapeWidth = W;
    }

    // GlassSurface.attachment for `glass`: the menu rect plus the corners
    // that join it to the glass (Shared/GlassJoin).
    function attachmentFor(glass) {
        if (glass !== hostGlass || shapeHeight <= 0 || shapeWidth <= 0)
            return null;
        return GlassJoin.attach({ width: glass.width, radius: glass.radius, stripY: glass.stripY, stripHeight: glass.stripHeight, framed: glass.hole.width > 0 }, shapeX - glass.x, shapeWidth, shapeHeight, down, fillet, menuRadius);
    }

    // An item's rect in host (bar) coordinates. Widgets on a side bar are
    // turned back upright, so both corners are mapped.
    function rectIn(item) {
        const a = item.mapToItem(host, 0, 0), b = item.mapToItem(host, item.width, item.height);
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }

    // Monitor-local rect of (a part of) an item. The bar window spans the
    // monitor along its edge and sits at that edge.
    function screenRect(item, x, y, w, h) {
        const r = bar.windowRect(item, x, y, w, h);
        const left = bar.edge === "right" ? bar.modelData.width - bar.width : 0;
        const top = bar.edge === "bottom" ? bar.modelData.height - bar.height : 0;
        return { x: left + r.x, y: top + r.y, width: r.width, height: r.height };
    }

    LeaveWatch {
        id: leave

        active: host.menu !== null
        pointerInside: host.pointerInside
        closeOnLeave: host.menu !== null && host.menu.closeOnLeave
        screenName: host.bar.modelData.name
        rects: () => [host.screenRect(area, 0, 0, area.width, area.height), host.screenRect(host, host.anchorStrip.x, host.anchorStrip.y, host.anchorStrip.width, host.anchorStrip.height)]
        onLeft: if (host.menu)
            host.menu.close()
    }

    Connections {
        target: host.menu

        function onMenuWidthChanged() {
            host.place(host.menu);
        }
    }

    // No glass to grow from (no panel, integrated widgets): the menu gets
    // its own glass just below the bar.
    GlassSurface {
        visible: host.hostGlass === null && host.shapeHeight > 0 && host.shapeWidth > 0
        x: host.shapeX
        y: area.y
        width: host.shapeWidth
        height: host.shapeHeight
        material: host.bar && host.bar.material ? host.bar.material : Theme.materials.bar
    }

    // The menu area: hover source, clip for the reveal, input region.
    MouseArea {
        id: area

        x: host.shapeX
        y: host.down ? host.bar.barHeight : -host.shapeHeight
        width: host.shapeWidth
        height: host.shapeHeight
        visible: height > 0
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        clip: true
        Keys.onEscapePressed: if (host.menu)
            host.menu.close()

        // Menus are parented here and positioned in content coordinates.
        Item {
            id: menuLayer

            x: -area.x
            y: -area.y
        }
    }
}
