import QtQuick
import qs.Core
import qs.Components.Glass

// In-window context popup, shared with launcher-like surfaces. Remaining
// inside the parent surface preserves its existing layer-shell focus grab.
Item {
    id: menu
    property var item: null
    property bool opened: false

    function close() { opened = false; }
    function open(anchor) {
        let host = anchor;
        while (host.parent) host = host.parent;
        overlay.parent = host;
        const p = anchor.mapToItem(host, anchor.width / 2, anchor.height);
        popup.x = Math.max(Theme.space.md, Math.min(p.x - popup.width / 2, host.width - popup.width - Theme.space.md));
        popup.y = Math.max(Theme.space.md, Math.min(p.y, host.height - popup.height - Theme.space.md));
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
            material: Theme.materials.popover
            width: actions.implicitWidth + Theme.space.sm * 2
            height: actions.implicitHeight + Theme.space.sm * 2
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
