import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Motion
import qs.Components.Popup
import qs.Modules
import qs.Modules.Bar
import "../../Shared/GlassJoin.js" as GlassJoin
import "DockGeometry.js" as Geometry

// A panel grown out of the dock (Placement.dockPanel on this screen, e.g. the
// control center): the dock glass grows a rect upward (GlassJoin) and the
// panel's content is drawn in it, so dock and panel are one surface – one
// material, radius, border and blur, no gap. The dock window grows at once
// when a panel opens and shrinks back once the close animation has finished.
//
// Closing, like a bar menu: the pointer leaves panel and dock (LeaveWatch,
// armed once the pointer has been inside), a click outside (focus grab, held
// while leaving can't close it), Esc, or another panel opens.
Item {
    id: host

    required property var dockWindow     // the dock's PanelWindow
    required property Item dockGlass     // the dock glass
    required property string screenName
    property string edge: "bottom"
    property Item dockBand: null         // the dock's hover band (counts as inside)

    readonly property var request: Placement.dockPanel && Placement.dockPanel.screen === screenName ? Placement.dockPanel : null
    // The request being drawn, kept through the close animation.
    property var shown: null
    readonly property bool open: request !== null
    readonly property real fillet: Theme.radius.lg
    readonly property real radius: Theme.radius.lg

    readonly property real targetHeight: request && loader.item ? loader.item.implicitHeight : 0
    property real shapeHeight: targetHeight
    readonly property real shapeWidth: loader.item ? Math.min(loader.item.implicitWidth, edge === "left" ? dockWindow.width-dockGlass.x-dockGlass.width-Theme.space.md : edge === "right" ? dockGlass.x-Theme.space.md : dockWindow.width - Theme.space.md * 2) : 0
    readonly property var panelRect: Geometry.panel(edge, {x:dockGlass.x,y:dockGlass.y,width:dockGlass.width,height:dockGlass.height}, dockWindow.width, dockWindow.height, shapeWidth, shapeHeight, Theme.space.md)
    readonly property real shapeX: panelRect.x
    // Room above the dock, kept from the start while a panel is placed on the
    // dock: resizing the window in use shows a frame without the glass (see
    // MenuHost.standingRoom).
    readonly property real standingRoom: Placement.dockHostsPanels ? Math.round(dockWindow.screen.height * 0.9) : 0
    readonly property real room: Math.max(standingRoom, targetHeight, shapeHeight)
    readonly property alias area: area
    property var grab: null
    readonly property bool wantsGrab: open && (!leave.closeOnLeave || !leave.hoverSeen)
    readonly property var hoverState: ({ edge: edge, dock: {x:dockGlass.x,y:dockGlass.y,width:dockGlass.width,height:dockGlass.height}, screen: screenName, panel: request ? request.id : "", pointer: leave.pointerInside, hoverSeen: leave.hoverSeen, grab: grab !== null, height: shapeHeight })

    Component.onCompleted: Placement.registerDockHost(host)
    Component.onDestruction: Placement.unregisterDockHost(host)

    Behavior on shapeHeight {
        BNumberAnimation {
            speed: "normal"
            curve: "emphasized"
        }
    }

    onRequestChanged: {
        if (request) {
            shown = request;
            leave.reset();
            Qt.callLater(() => {
                if (host.open)
                    area.forceActiveFocus();
            });
        }
        Qt.callLater(updateGrab);
    }
    onShapeHeightChanged: if (shapeHeight <= 0 && !request)
        shown = null
    onWantsGrabChanged: Qt.callLater(updateGrab)

    function close() {
        if (request)
            request.close();
    }

    function updateGrab() {
        if (wantsGrab && !grab) {
            grab = Compositor.createFocusGrab([dockWindow], () => {
                host.grab = null;
                if (host.request)
                    PopupGroup.noteDismissed(host.request.id);
                host.close();
            });
        } else if (!wantsGrab && grab) {
            grab.release();
            grab = null;
        }
    }

    // GlassSurface.attachment for the dock dockGlass.
    function screenAttachment() {
        if (shapeHeight <= 0 || shapeWidth <= 0) return null;
        return GlassJoin.between({x:dockGlass.x,y:dockGlass.y,width:dockGlass.width,height:dockGlass.height}, panelRect, edge, fillet, radius, false);
    }
    function attachment() {
        return GlassJoin.transform(screenAttachment(), (x,y) => Qt.point(x-dockGlass.x,y-dockGlass.y));
    }
    // The dock uses a full-screen, input-masked surface on every edge.
    function screenRect(item) {
        const a = item.mapToItem(null,0,0), b = item.mapToItem(null,item.width,item.height);
        return {x:Math.min(a.x,b.x),y:Math.min(a.y,b.y),width:Math.abs(b.x-a.x),height:Math.abs(b.y-a.y)};
    }

    LeaveWatch {
        id: leave

        active: host.open
        pointerInside: area.containsMouse || (host.dockBand !== null && host.dockBand.containsMouse)
        screenName: host.screenName
        rects: () => [host.screenRect(area), host.screenRect(host.dockGlass)]
        onLeft: host.close()
    }

    // The panel area: hover source, clip for the reveal, input region. Its
    // content sits at its final place, so the part next to the dock shows
    // first as the shape grows.
    MouseArea {
        id: area

        x: host.shapeX
        y: host.panelRect.y
        width: host.shapeWidth
        height: host.shapeHeight
        visible: height > 0
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        clip: true
        Keys.onEscapePressed: host.close()

        Loader {
            id: loader

            y: host.edge === "bottom" ? area.height - (item ? item.implicitHeight : 0) : 0
            width: host.shapeWidth
            active: host.shown !== null
            sourceComponent: host.shown ? host.shown.component : null
            focus: true
        }

        // Panels that can shrink (the launcher) fit between the dock and the
        // top of the screen.
        Binding {
            target: loader.item
            property: "maxHeight"
            value: Math.max(Theme.control.height.lg, (host.edge === "bottom" ? host.dockGlass.y - Metrics.edgeSpace("top") : host.edge === "top" ? host.dockWindow.height - host.dockGlass.y - host.dockGlass.height - Metrics.edgeSpace("bottom") : host.dockWindow.height - Metrics.edgeSpace("top") - Metrics.edgeSpace("bottom")) - Theme.space.xl)
            when: loader.item !== null && loader.item.maxHeight !== undefined
        }
    }
}
