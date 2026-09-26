import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Shared
import "DockGeometry.js" as Geometry

// Keep menu input on the same layer surface as the dock and its previews.
Item {
    id: menu
    property var item: null
    property Item anchorItem: null
    required property var dockWindow
    property string side: "top"
    property var grab: null
    readonly property real padding: Theme.space.sm
    readonly property string edge: side === "top" ? "bottom" : side === "bottom" ? "top" : side === "left" ? "right" : "left"
    readonly property var anchorRect: {
        if (!anchorItem) return {x:0,y:0,width:0,height:0};
        const a=anchorItem.mapToItem(menu.parent,0,0);
        const b=anchorItem.mapToItem(menu.parent,anchorItem.width,anchorItem.height);
        return {x:Math.min(a.x,b.x),y:Math.min(a.y,b.y),width:Math.abs(b.x-a.x),height:Math.abs(b.y-a.y)};
    }
    readonly property var placement: Geometry.panel(edge,anchorRect,dockWindow.width,dockWindow.height,width,height,Theme.space.sm)
    x: placement.x
    y: placement.y
    width: content.implicitWidth + padding*2
    height: content.implicitHeight + padding*2
    visible: false
    z: 101
    function open() { visible=true; forceActiveFocus(); }
    function close() { visible=false; }
    Keys.onEscapePressed: close()
    onVisibleChanged: {
        if (visible) {
            content.showingInfo=false;
            grab=Compositor.createFocusGrab([dockWindow], () => { menu.grab=null; menu.close(); });
        } else {
            if (grab) grab.release();
            grab=null;
        }
    }
    GlassSurface { anchors.fill:parent; material:menu.dockWindow.joined ? Theme.materials.bar : Theme.materials.popover }
    // Padding consumes clicks too; only clicks beyond the menu dismiss it.
    MouseArea { anchors.fill:parent; acceptedButtons:Qt.AllButtons }
    AppMenuContent {
        id: content
        x:menu.padding; y:menu.padding
        item:menu.item
        onCloseRequested:menu.close()
    }
}
