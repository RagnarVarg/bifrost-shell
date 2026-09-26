import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.Text
import qs.Modules
import qs.Services
import "OverviewLayout.js" as Layout

Scope {
    id: overview
    readonly property bool open: ShellState.overviewOpen && !ShellState.locked
    property var grab: null
    property var surfaces: []
    function close() { ShellState.overviewOpen=false; }
    function updateGrab() {
        if (grab) {grab.release();grab=null;}
        if (open && surfaces.length) grab=Compositor.createFocusGrab(surfaces,()=>{grab=null;close();});
    }
    onOpenChanged: {
        if (open) Compositor.retainGeometry(); else Compositor.releaseGeometry();
        Qt.callLater(updateGrab);
    }
    Component.onDestruction: { if (grab) grab.release(); if (open) Compositor.releaseGeometry(); }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            visible: overview.open || visual.opacity > 0
            color: "transparent"
            anchors { top:true; bottom:true; left:true; right:true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: RunMode.layerNamespace("overview")
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: overview.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            Component.onCompleted: { overview.surfaces=overview.surfaces.concat([window]); if(overview.open)Qt.callLater(overview.updateGrab); }
            Component.onDestruction: {overview.surfaces=overview.surfaces.filter(w=>w!==window);if(overview.open)Qt.callLater(overview.updateGrab);}
            property var selected: null
            property string dragged: ""
            property var dropWorkspace: null
            readonly property var workspaces: {
                const out=Compositor.workspaces.filter(w=>!w.special).slice();
                for(let i=1;i<=Config.values.workspaces.persistent;++i)
                    if(!out.some(w=>w.id===i))out.push({id:i,name:String(i),active:false,monitor:""});
                const next=Math.max(0,...out.map(w=>w.id))+1;
                out.push({id:next,name:String(next)+" +",active:false,monitor:""});
                return out.sort((a,b)=>a.id-b.id);
            }
            readonly property var wins: Compositor.windows.filter(w=>w.monitor===window.modelData.name && (selected===null || w.workspaceId===selected))
            readonly property var boxes: Layout.layout(wins,area.width,area.height,Theme.space.xl,Theme.control.height.md)
            ListModel { id: tiles }
            onWinsChanged: if(!dragged)Layout.sync(tiles,wins.map(w=>String(w.id)))
            onDraggedChanged: if(!dragged)Layout.sync(tiles,wins.map(w=>String(w.id)))
            onVisibleChanged: if(visible) {selected=null;Layout.sync(tiles,wins.map(w=>String(w.id)));keys.forceActiveFocus();}
            function targetAt(item,x,y) {
                const p=item.mapToItem(workspaceRow,x,y);
                dropWorkspace=null;
                for(let i=0;i<workspaceRepeater.count;++i) {
                    const tile=workspaceRepeater.itemAt(i);
                    if(p.x>=tile.x && p.x<=tile.x+tile.width && p.y>=0 && p.y<=tile.height) {dropWorkspace=tile.modelData.id;break;}
                }
            }
            Item {
                id: visual
                anchors.fill: parent
                opacity: overview.open ? 1 : 0
                scale: overview.open ? 1 : 0.98
                enabled: overview.open
                Behavior on opacity { BNumberAnimation {} }
                Behavior on scale { BNumberAnimation { curve: "decelerate" } }
            Rectangle { anchors.fill:parent; color:Theme.color.shadow; opacity:Theme.opacity.disabled }
            MouseArea { anchors.fill:parent; onClicked:overview.close() }
            Item { id:keys; focus:overview.open; Keys.onEscapePressed:overview.close() }
            GlassSurface {
                id: strip
                x:Theme.space.xl; y:Theme.space.xl
                width:parent.width-Theme.space.xl*2
                height:Theme.control.height.lg+Theme.space.md*2
                material:Theme.materials.panel
                Flickable {
                    anchors.fill:parent; anchors.margins:Theme.space.md
                    contentWidth:workspaceRow.width; clip:true
                    Row {
                        id:workspaceRow
                        spacing:Theme.space.sm
                        Repeater {
                            id:workspaceRepeater
                            model:window.workspaces
                            delegate:Rectangle {
                                required property var modelData
                                width:Math.max(label.implicitWidth+Theme.space.xl*2,Theme.control.height.lg*2)
                                height:Theme.control.height.lg
                                radius:Theme.radius.md
                                color:window.dropWorkspace===modelData.id ? Theme.color.accent : Theme.color.controlFill
                                border.width:modelData.active ? Theme.border.focus : Theme.border.hairline
                                border.color:modelData.active ? Theme.color.accent : Theme.color.hairline
                                BText {id:label;anchors.centerIn:parent;role:"label";text:I18n.tr("Workspace %1").arg(modelData.name || modelData.id)+(modelData.monitor && modelData.monitor!==window.modelData.name ? " · "+modelData.monitor : "")}
                                MouseArea {anchors.fill:parent;onClicked:window.selected=window.selected===parent.modelData.id ? null : parent.modelData.id}
                            }
                        }
                    }
                }
            }
            BText {
                id:heading
                x:Theme.space.xl;y:strip.y+strip.height+Theme.space.lg
                text:window.selected===null ? I18n.tr("Window overview") : I18n.tr("Workspace %1").arg(window.selected)
                role:"heading"
            }
            Item {
                id:area
                x:Theme.space.xl;y:heading.y+heading.height+Theme.space.lg
                width:parent.width-Theme.space.xl*2;height:parent.height-y-Theme.space.xl
                BText {anchors.centerIn:parent;visible:window.wins.length===0;text:I18n.tr("No open windows");role:"heading"}
                Repeater {
                    model:tiles
                    delegate:Item {
                        id:tile
                        required property string key
                        readonly property var win:window.wins.find(w=>String(w.id)===key)
                        readonly property var box:window.boxes.find(b=>b.key===key) || ({x:0,y:0,width:0,height:0})
                        readonly property var app:win ? Apps.forAppId(win.appId) : null
                        property real offsetX:0
                        property real offsetY:0
                        x:box.x+offsetX;y:box.y+offsetY
                        width:box.width;height:box.height+Theme.control.height.md
                        z:window.dragged===key ? 10 : 0
                        visible:!!win
                        GlassSurface {
                            anchors.fill:parent
                            material:Theme.materials.panel
                            Rectangle {anchors.fill:parent;color:"transparent";radius:Theme.radius.md;border.width:mouse.containsMouse ? Theme.border.focus : 0;border.color:Theme.color.accent}
                            WindowCapture {id:capture;width:parent.width;height:tile.box.height;source:tile.win ? Compositor.captureSource(tile.win.id) : null;live:overview.open && tile.visible}
                            Image {anchors.centerIn:capture;width:Theme.icon.size.xl;height:width;source:tile.app ? tile.app.icon : "";visible:!capture.hasContent}
                            Row {
                                x:Theme.space.sm;y:tile.box.height;spacing:Theme.space.sm
                                height:Theme.control.height.md
                                Image {anchors.verticalCenter:parent.verticalCenter;width:Theme.icon.size.sm;height:width;source:tile.app ? tile.app.icon : ""}
                                BText {anchors.verticalCenter:parent.verticalCenter;width:Math.max(0,tile.width-Theme.icon.size.sm-Theme.space.sm*3);text:tile.win ? tile.win.title : "";elide:Text.ElideRight;role:"label"}
                            }
                        }
                        MouseArea {
                            id:mouse
                            anchors.fill:parent;hoverEnabled:true;cursorShape:pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            property point start
                            property bool moved:false
                            onPressed:m=>{start=mapToItem(area,m.x,m.y);moved=false;}
                            onPositionChanged:m=>{
                                if(!pressed)return;
                                const p=mapToItem(area,m.x,m.y);
                                if(!moved && Math.hypot(p.x-start.x,p.y-start.y)<Theme.space.sm)return;
                                moved=true;window.dragged=tile.key;
                                tile.offsetX=p.x-start.x;tile.offsetY=p.y-start.y;
                                window.targetAt(mouse,m.x,m.y);
                            }
                            onReleased:{
                                if(moved && window.dropWorkspace!==null && tile.win)Compositor.moveWindowToWorkspace(tile.win.id,window.dropWorkspace);
                                tile.offsetX=0;tile.offsetY=0;window.dragged="";window.dropWorkspace=null;
                            }
                            onCanceled:{tile.offsetX=0;tile.offsetY=0;window.dragged="";window.dropWorkspace=null;}
                            onClicked:if(!moved && tile.win){const id=tile.win.id;overview.close();Compositor.focusWindow(id);}
                        }
                    }
                }
            }
            }
        }
    }
}
