import QtQuick
import qs.Core
import qs.Components.Glass

// In-window context popup, shared with launcher-like surfaces. It stays inside
// `bounds` (default: the item it is declared in), so it is part of that
// surface: a bar or dock menu counts the pointer on it as inside (hover-leave
// closing, input region), and the surface's layer-shell focus grab still holds.
// Below the anchor, or above it when there is more room there.
Item {
    id: menu
    property var item: null
    property bool opened: false
    property Item bounds: parent
    // The anchor in bounds coordinates: centre x, top and bottom edges.
    property real anchorX: 0
    property real anchorTop: 0
    property real anchorBottom: 0

    function close() { opened = false; }
    function open(anchor) {
        overlay.parent = bounds;
        const top = anchor.mapToItem(bounds, anchor.width / 2, 0);
        anchorX = top.x;
        anchorTop = top.y;
        anchorBottom = top.y + anchor.height;
        actions.showingInfo = false;
        opened = true;
        overlay.forceActiveFocus();
    }

    Item {
        id: overlay
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: menu.opened
        z: 1000
        Keys.onEscapePressed: menu.close()
        MouseArea { anchors.fill: parent; onPressed: menu.close() }
        GlassSurface {
            id: popup
            readonly property real edge: Theme.space.md
            readonly property bool above: menu.anchorBottom + height + edge > overlay.height && menu.anchorTop > overlay.height - menu.anchorBottom
            material: Theme.materials.popover
            width: actions.implicitWidth + Theme.space.sm * 2
            height: actions.implicitHeight + Theme.space.sm * 2
            x: Math.max(edge, Math.min(menu.anchorX - width / 2, overlay.width - width - edge))
            y: Math.max(edge, Math.min(above ? menu.anchorTop - height : menu.anchorBottom, overlay.height - height - edge))
            MouseArea { anchors.fill: parent }
            AppMenuContent {
                id: actions
                x: Theme.space.sm
                y: Theme.space.sm
                item: menu.item
                onCloseRequested: menu.close()
            }
        }
    }
}
