import QtQuick
import Quickshell
import qs.Compositor
import qs.Core
import qs.Components.Glass

// Glass popup anchored to an item (e.g. a bar widget). Children go on the
// glass. Closes on outside click (compositor focus grab when supported), Esc,
// and when another menu opens (PopupGroup: one menu at a time).
//   BPopup { id: p; anchorItem: button; BText { … } }   p.open() / p.close()
PopupWindow {
    id: popup

    property Item anchorItem: null
    property bool above: false
    property string side: above ? "top" : "bottom"
    property var material: Theme.materials.popover
    property real padding: Theme.space.sm
    // Tooltips set this false: a grab would steal pointer input.
    property bool grabFocus: true
    // Other windows that should not count as "outside". Bar menus leave the
    // bar out: a click anywhere outside the menu closes it.
    property var extraGrabWindows: []
    property real contentWidth: contentArea.childrenRect.width
    property real contentHeight: contentArea.childrenRect.height

    default property alias content: contentArea.data

    readonly property real shadow: glass.shadowExtent
    property var grab: null

    signal dismissed

    function open() {
        visible = true;
    }

    function close() {
        visible = false;
    }

    function toggle() {
        if (!visible && PopupGroup.justDismissed(popup))
            return;
        visible = !visible;
    }

    color: "transparent"
    visible: false
    implicitWidth: contentWidth + padding * 2 + shadow * 2
    implicitHeight: contentHeight + padding * 2 + shadow * 2

    anchor.item: anchorItem
    anchor.rect.x: side === "left" ? -implicitWidth + shadow : side === "right" ? (anchorItem ? anchorItem.width : 0) - shadow : anchorItem ? (anchorItem.width - implicitWidth) / 2 : 0
    anchor.rect.y: side === "left" || side === "right" ? (anchorItem ? (anchorItem.height-implicitHeight)/2 : 0) : side === "top" ? -implicitHeight + shadow - Theme.space.xs : (anchorItem ? anchorItem.height : 0) - shadow + Theme.space.xs

    mask: Region { item: glass }

    onVisibleChanged: {
        if (visible && grabFocus)
            PopupGroup.register(popup);
        if (!visible)
            PopupGroup.unregister(popup);
        if (visible && grabFocus) {
            grab = Compositor.createFocusGrab([popup].concat(extraGrabWindows), () => {
                popup.grab = null;
                PopupGroup.noteDismissed(popup);
                popup.visible = false;
            });
        } else if (!visible) {
            if (grab)
                grab.release();
            grab = null;
            dismissed();
        }
    }

    GlassSurface {
        id: glass

        x: popup.shadow
        y: popup.shadow
        width: popup.width - popup.shadow * 2
        height: popup.height - popup.shadow * 2
        material: popup.material

        Item {
            id: contentArea

            x: popup.padding
            y: popup.padding
            width: glass.width - popup.padding * 2
            height: glass.height - popup.padding * 2
            focus: true
            Keys.onEscapePressed: popup.close()
        }
    }
}
