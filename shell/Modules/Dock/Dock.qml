import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Components.Motion
import qs.Modules
import qs.Services
import qs.Modules.Bar
import qs.Components.Text
import "DockGeometry.js" as Geometry
import "../../Shared/GlassJoin.js" as GlassJoin
import "DockModel.js" as DockModel

// Low dock at the bottom of each screen: pinned apps, then running ones.
// Panels placed on the dock (Placement, e.g. the control center) grow out of
// its glass (DockPanelHost); the dock stays shown while one is open.
// Auto-hide works like the bar's (shared AutoHide controller): one hover
// band from the screen edge up through the dock, no reserved space while
// auto-hiding, and "smart" keeps it shown while no window covers it.
Scope {
    id: dock

    readonly property var cfg: Config.values.dock
    readonly property var entries: {
        const items = DockModel.build(cfg.pinned || [], Compositor.windows, cfg.showRunning, id => Apps.forAppId(id), id => Apps.byId(id));
        if (cfg.overview && cfg.overview.enabled) items.push({key:"bifrost-overview",kind:"overview",app:null,pinned:false,windows:[]});
        if (cfg.trash && cfg.trash.enabled) items.push({key:"bifrost-trash",kind:"trash",app:null,pinned:false,windows:[]});
        return DockModel.withLauncher(DockModel.ordered(items, cfg.order), cfg.launcher && cfg.launcher.enabled, cfg.launcher ? cfg.launcher.index : 0);
    }
    ListModel { id: stableEntries }
    onEntriesChanged: DockModel.syncKeys(stableEntries, entries.map(e => e.key))
    Component.onCompleted: DockModel.syncKeys(stableEntries, entries.map(e => e.key))
    readonly property int pinnedCount: entries.filter(e => e.pinned).length
    readonly property int firstRunningIndex: entries.findIndex(e => !e.pinned && !e.kind)

    Binding {
        target: Placement
        property: "dockEntries"
        value: dock.cfg.enabled ? dock.entries.length : 0
    }

    Variants {
        model: dock.cfg.enabled ? Quickshell.screens : []

        delegate: PanelWindow {
            id: window

            required property var modelData

            readonly property string edge: dock.cfg.position || "bottom"
            readonly property bool vertical: edge === "left" || edge === "right"
            readonly property bool free: edge === "free"
            readonly property bool joined: Metrics.frame && !free
            readonly property var insets: ({left: Metrics.edgeSpace("left"), right: Metrics.edgeSpace("right"), top: Metrics.edgeSpace("top"), bottom: Metrics.edgeSpace("bottom")})
            property string reorderKey: ""
            property string reorderBefore: ""
            property real reorderLine: 0
            function moveIcon(item, px, py) {
                previewHost.close();
                reorderKey=item.model.key;
                const point=item.mapToItem(row,px,py);
                reorderBefore=""; reorderLine=row.width;
                for (let i=0;i<dockRepeater.count;++i) {
                    const slot=dockRepeater.itemAt(i);
                    if (point.x < slot.x+slot.width/2) {
                        reorderBefore=slot.entryKey; reorderLine=slot.x; break;
                    }
                }
            }
            function finishIcon(commit) {
                if (commit && reorderKey && reorderBefore !== reorderKey) {
                    const keys=DockModel.dropOrder(dock.entries.map(e=>e.key),reorderKey,reorderBefore);
                    Config.set("dock.order",DockModel.rememberOrder(dock.cfg.order,keys.filter(k=>k!=="bifrost-launcher")));
                    if (keys.indexOf("bifrost-launcher") >= 0) Config.set("dock.launcher.index",keys.indexOf("bifrost-launcher"));
                    Config.set("dock.pinned",DockModel.rememberOrder(dock.cfg.pinned,keys.filter(k=>(dock.cfg.pinned || []).indexOf(k)>=0)));
                }
                reorderKey=""; reorderBefore="";
            }
            property real freeX: dock.cfg.freeX === undefined ? 0.5 : dock.cfg.freeX
            property real freeY: dock.cfg.freeY === undefined ? 0.85 : dock.cfg.freeY
            readonly property real handleSize: free ? Theme.control.height.sm : 0
            readonly property var geometry: Geometry.rect(edge, width, height,
                row.implicitWidth + (Theme.space.sm + Metrics.dockExtraPadding) * 2 + handleSize,
                dockHeight, insets, joined || free ? 0 : Metrics.dockMargin, freeX, freeY)
            readonly property var frameAttachment: {
                if (!joined || !dock.entries.length) return null;
                const rect=Geometry.frameExtension(edge,{x:glass.x,y:glass.y,width:glass.width,height:glass.height},width,height,Metrics.edgeSpace(edge));
                if (!rect) return null;
                const t = Metrics.edgeSpace(edge);
                const base = edge === "bottom" ? {x:0,y:height-t,width:width,height:t} : edge === "top" ? {x:0,y:0,width:width,height:t} : edge === "left" ? {x:0,y:0,width:t,height:height} : {x:width-t,y:0,width:t,height:height};
                return GlassJoin.between(base, rect, edge, Theme.radius.lg, Theme.materials.bar.radius, true);
            }
            readonly property var framePanelAttachment: joined && revealed ? panelHost.screenAttachment() : null
            Component.onCompleted: ShellState.registerDock(window)
            Component.onDestruction: ShellState.unregisterDock(window)

            readonly property real dockHeight: Metrics.dockHeight
            readonly property real bandHeight: dockHeight + Metrics.dockMargin + Theme.space.xs
            readonly property bool revealed: autoHide.revealed
            readonly property bool reserve: RunMode.reservesScreenSpace && !dock.cfg.autohide && !free && dock.entries.length > 0

            AutoHide {
                id: autoHide

                enabled: dock.cfg.autohide && !window.free
                smart: dock.cfg.smartHide
                pointerInside: band.containsMouse || (revealStrip.active && revealStrip.containsMouse)
                pinned: menu.visible || panelHost.open || previewHost.open || dragHandle.pressed || window.reorderKey !== ""
                screenName: window.modelData.name
                area: ({ x: band.x, y: band.y, width: band.width, height: band.height })
                delayMs: Theme.motion.duration.emphasis
            }

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: RunMode.layerNamespace("dock")
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: panelHost.open || menu.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: -1

            FrameReserve {
                screen: window.screen
                edge: window.free ? "bottom" : window.edge
                size: window.reserve ? window.dockHeight + (window.joined ? 0 : Metrics.dockMargin) : 0
            }

            mask: Region {
                item: menu.visible ? menuDismissArea : window.revealed ? (dock.cfg.autohide && !window.free ? band : glass) : revealStrip

                Region { item: revealStrip.active ? revealStrip : null }
                Region { item: previewHost.open ? previewHost : null }
                Region {
                    item: panelHost.area.visible ? panelHost.area : null
                }
            }

            MouseArea {
                id: band

                x: window.vertical ? (window.edge === "left" ? 0 : window.geometry.x) : window.geometry.x
                y: window.vertical ? window.geometry.y : (window.edge === "top" ? 0 : window.geometry.y)
                width: window.vertical ? window.geometry.width + (window.edge === "left" ? window.geometry.x : window.width-window.geometry.x-window.geometry.width) : window.geometry.width
                height: window.vertical ? window.geometry.height : window.geometry.height + (window.edge === "top" ? window.geometry.y : window.height-window.geometry.y-window.geometry.height)
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // The whole screen edge reveals the dock, not only the part below
            // it; it stays in the input mask while revealed so a pointer
            // resting on the edge beside the dock keeps it shown.
            MouseArea {
                id: revealStrip

                readonly property bool active: dock.cfg.autohide && !window.free && !menu.visible
                x: window.edge === "right" ? window.width-width : 0
                y: window.edge === "bottom" ? window.height-height : 0
                width: window.vertical ? Theme.space.xs : window.width
                height: window.vertical ? window.height : Theme.space.xs
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // Keep dock coordinates screen-local, but clip its artwork at
            // the frame's inner edge. Icons disappear into the frame instead
            // of being painted over it during the slide animation.
            Item {
                id: dockViewport
                x: window.joined ? window.insets.left : 0
                y: window.joined ? window.insets.top : 0
                width: Math.max(0,window.width-x-(window.joined ? window.insets.right : 0))
                height: Math.max(0,window.height-y-(window.joined ? window.insets.bottom : 0))
                clip: window.joined

                Item {
                    x: -dockViewport.x
                    y: -dockViewport.y
                    width: window.width
                    height: window.height
                    GlassSurface {
                        id: glass

                        material: Theme.materials.dock
                        paintEnabled: !window.joined
                        // Kept at the bottom as the window grows for a panel; only the
                        // hide offset animates.
                        property real hideOffset: window.revealed ? 0 : window.dockHeight + Metrics.dockMargin + shadowExtent

                        x: window.geometry.x + (window.edge === "left" ? -hideOffset : window.edge === "right" ? hideOffset : 0)
                        y: window.geometry.y + (window.edge === "top" ? -hideOffset : window.edge === "bottom" ? hideOffset : 0)
                        attachment: panelHost.attachment()
                        width: window.geometry.width
                        height: window.geometry.height
                        visible: dock.entries.length > 0

                        Behavior on hideOffset {
                            BNumberAnimation {
                                speed: "normal"
                                curve: "emphasized"
                            }
                        }

                        Behavior on width {
                            BNumberAnimation {}
                        }

                        MouseArea {
                            id: dragHandle
                            visible: window.free
                            width: window.handleSize
                            height: parent.height
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property point startPointer
                            property point startDock
                            onPressed: mouse => {
                                startPointer = mapToItem(null, mouse.x, mouse.y);
                                startDock = Qt.point(glass.x,glass.y);
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                const point = mapToItem(null,mouse.x,mouse.y);
                                window.freeX = Geometry.clamp((startDock.x+point.x-startPointer.x-window.insets.left) / Math.max(1,window.width-window.insets.left-window.insets.right-glass.width),0,1);
                                window.freeY = Geometry.clamp((startDock.y+point.y-startPointer.y-window.insets.top) / Math.max(1,window.height-window.insets.top-window.insets.bottom-glass.height),0,1);
                            }
                            onReleased: {
                                Config.set("dock.freeX",window.freeX);
                                Config.set("dock.freeY",window.freeY);
                                window.freeX = Qt.binding(() => dock.cfg.freeX);
                                window.freeY = Qt.binding(() => dock.cfg.freeY);
                            }
                            BText { anchors.centerIn: parent; text: "⠿"; role: "label"; tone: "muted" }
                        }

                        Row {
                            id: row
                            // Rotate the strip, then counter-rotate each square app.
                            rotation: window.vertical ? 90 : 0
                            x: (parent.width-width+window.handleSize)/2
                            y: (parent.height-height)/2
                            spacing: Theme.space.xxs

                            Repeater {
                                id: dockRepeater
                                model: stableEntries

                                delegate: Row {
                                    id: slot

                                    required property int index
                                    required property string entryKey
                                    z: dockItem.hovered || dockItem.dragging ? 1 : 0
                                    readonly property var modelData: dock.entries.find(e => e.key === entryKey) || ({key:entryKey,app:null,pinned:false,windows:[]})

                                    spacing: Theme.space.xxs

                                    // Separator between pinned and running-only apps
                                    Rectangle {
                                        visible: !(dock.cfg.order || []).length && slot.index === dock.firstRunningIndex && dock.pinnedCount > 0
                                        width: Theme.border.hairline
                                        height: Metrics.dockIconSize * 0.6
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Theme.color.divider
                                    }

                                    DockItem {
                                        id: dockItem

                                        rotation: window.vertical ? -90 : 0
                                        screenName: window.modelData.name
                                        edge: window.free ? (window.geometry.y < window.height/2 ? "top" : "bottom") : window.edge
                                        model: slot.modelData
                                        opacity: dragging ? Theme.opacity.disabled : 1
                                        onReorderMoved: (item,x,y) => window.moveIcon(item,x,y)
                                        onReorderEnded: commit => window.finishIcon(commit)
                                        onLabelRequested: item => labelHost.owner=item
                                        onPreviewRequested: item => previewHost.show(item)
                                        onPreviewDismissed: if (previewHost.owner === dockItem) previewHost.close()
                                        onContextMenu: {
                                            if (!!slot.modelData.kind) { Launch.openSettings("dock"); return; }
                                            menu.anchorItem = dockItem;
                                            menu.item = slot.modelData;
                                            menu.open();
                                        }
                                    }
                                }
                            }
                        }
                    }

                }
            }

            Rectangle {
                parent: glass
                rotation: window.vertical ? 90 : 0
                transformOrigin: Item.TopLeft
                visible: window.reorderKey !== ""
                x: row.mapToItem(glass,window.reorderLine,0).x
                y: row.mapToItem(glass,window.reorderLine,0).y
                width: Theme.border.focus
                height: row.height
                radius: width/2
                color: Theme.color.accent
            }

            // Hover labels share this surface, like previews. A native popup
            // can consume the first click intended for its anchor icon.
            GlassSurface {
                id: labelHost
                property var owner: null
                readonly property var labelRect: owner ? previewHost.screenRect(owner) : ({x:0,y:0,width:0,height:0})
                readonly property var placement: Geometry.panel(owner ? owner.edge : "bottom",labelRect,window.width,window.height,width,height,Theme.space.sm)
                visible: owner !== null && owner.labelOpen && owner.hovered && !owner.dragging && !previewHost.open && !menu.visible && !ShellState.launcherOpen
                x: placement.x
                y: placement.y
                width: Math.min(labelText.implicitWidth+Theme.space.md*2,Theme.layout.editorWidth)
                height: labelText.implicitHeight+Theme.space.sm*2
                material: Theme.materials.tooltip
                z: 2
                BText {
                    id: labelText
                    anchors.fill:parent
                    anchors.margins:Theme.space.sm
                    text:labelHost.owner ? labelHost.owner.name : ""
                    role:"label"
                    elide:Text.ElideRight
                    horizontalAlignment:Text.AlignHCenter
                }
            }

            DockPreview {
                id: previewHost
                screenName: window.modelData.name
                screenWidth: window.width
                screenHeight: window.height
            }

            // The inline menu sits above this dismissal area on the same surface.
            MouseArea {
                id: menuDismissArea
                anchors.fill: parent
                z: 100
                visible: menu.visible
                acceptedButtons: Qt.AllButtons
                onPressed: menu.close()
            }

            DockMenu {
                id: menu
                dockWindow: window
                side: window.edge === "left" ? "right" : window.edge === "right" ? "left" : window.edge === "top" ? "bottom" : "top"
            }

            DockPanelHost {
                id: panelHost

                anchors.fill: parent
                dockWindow: window
                dockGlass: glass
                edge: window.free ? (window.geometry.y < window.height/2 ? "top" : "bottom") : window.edge
                dockBand: band
                screenName: window.modelData.name
            }

            // Dev aid: BIFROST_DEV_OPEN_DOCK=<index> opens that entry's menu at start.
            Timer {
                running: Platform.env("BIFROST_DEV_OPEN_DOCK") !== ""
                interval: 2000
                onTriggered: {
                    const i = Number(Platform.env("BIFROST_DEV_OPEN_DOCK"));
                    const slot = row.children[i];
                    if (!slot)
                        return;
                    menu.anchorItem = slot.children[1];
                    menu.item = dock.entries[i];
                    menu.open();
                }
            }
        }
    }
}
