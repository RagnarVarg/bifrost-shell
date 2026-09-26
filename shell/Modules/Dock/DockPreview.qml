import QtQuick
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Components.Text
import qs.Modules.Bar
import "DockGeometry.js" as Geometry
import "DockModel.js" as DockModel

// A preview lives in the dock surface, so pointer transitions never cross
// native popup windows. LeaveWatch verifies apparent leaves with Hyprland.
Item {
    id: host
    property var owner: null
    property string screenName: ""
    property real screenWidth: 0
    property real screenHeight: 0
    readonly property bool open: owner !== null && owner.previewEnabled
    readonly property string edge: owner ? owner.edge : "bottom"
    readonly property var windows: open ? owner.model.windows : []
    readonly property var windowIds: windows.slice(0, 4).map(w => String(w.id))
    readonly property real padding: Theme.space.sm
    readonly property var anchorRect: owner ? screenRect(owner) : ({x:0,y:0,width:0,height:0})
    readonly property var placement: Geometry.panel(edge, anchorRect, screenWidth, screenHeight, width, height, Theme.space.sm)
    x: placement.x
    y: placement.y
    width: Math.min(Theme.layout.editorWidth + padding * 2, screenWidth - Theme.space.sm * 2)
    height: Math.min(contents.implicitHeight + padding * 2, screenHeight - Theme.space.sm * 2)
    visible: open
    z: 1

    ListModel { id: stableWindows }
    onWindowIdsChanged: DockModel.syncKeys(stableWindows, windowIds)
    onOpenChanged: if (!open) owner = null

    function screenRect(item) {
        const a = item.mapToItem(null, 0, 0), b = item.mapToItem(null, item.width, item.height);
        return {x:Math.min(a.x,b.x), y:Math.min(a.y,b.y), width:Math.abs(b.x-a.x), height:Math.abs(b.y-a.y)};
    }
    function show(item) {
        if (!item || !item.previewEnabled) return;
        owner = item;
        leave.reset();
        // Opening is only requested after hovering the owner.
        leave.hoverSeen = true;
        if (!leave.pointerInside) leave.restart();
    }
    function close() { owner = null; }

    LeaveWatch {
        id: leave
        active: host.open
        closeOnLeave: true
        interval: Theme.motion.duration.slow
        pointerInside: previewHover.hovered || (host.owner !== null && host.owner.hovered)
        screenName: host.screenName
        rects: () => leave.panelRects(host.screenRect(host), host.anchorRect, host.edge)
        onLeft: host.close()
    }

    HoverHandler { id: previewHover }
    GlassSurface {
        anchors.fill: parent
        material: Theme.materials.tooltip
    }
    Flickable {
        anchors.fill: parent
        anchors.margins: host.padding
        contentWidth: width
        contentHeight: contents.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: contents
            width: parent.width
            spacing: Theme.space.sm
            BText { text: host.owner ? host.owner.name : ""; role: "caption" }
            Repeater {
                model: stableWindows
                delegate: Column {
                    id: preview
                    required property string entryKey
                    readonly property var windowData: host.windows.find(w => String(w.id) === entryKey) || ({})
                    width: contents.width
                    spacing: Theme.space.xs
                    Item {
                        width: parent.width
                        height: width * 0.6
                        Rectangle { anchors.fill: parent; radius: Theme.radius.sm; color: Theme.color.controlFill }
                        WindowCapture {
                            id: capture
                            anchors.fill: parent
                            source: Compositor.supports("windowCapture") ? Compositor.captureSource(preview.entryKey) : null
                            live: host.open
                        }
                        BText { anchors.centerIn: parent; visible: !capture.hasContent; text: I18n.tr("Preview unavailable"); role: "caption" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const id = preview.windowData.id;
                                host.close();
                                if (id) Compositor.focusWindow(id);
                            }
                        }
                    }
                    BText { width: parent.width; text: preview.windowData.title || (host.owner ? host.owner.name : ""); role: "caption"; elide: Text.ElideRight }
                }
            }
        }
    }
}
