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
            // selected: null = every window (minimized ones dimmed), a
            // workspace id, or "minimized". A minimized window is listed on
            // the monitor it returns to; clicking it restores it.
            readonly property var wins: Layout.visible(Compositor.windows,window.modelData.name,selected)
            readonly property int minimizedCount: Compositor.windows.filter(w=>w.minimized===true && w.monitor===window.modelData.name).length
            // Pictures are capped (Theme.layout.overview*) so the overview stays
            // a zoomed-out map of the windows, even with only one or two.
            readonly property real tileMaxHeight:window.height*Theme.layout.overviewTileHeight
            readonly property var boxes: Layout.layout(wins,area.width,area.height,Theme.layout.overviewGap,Theme.control.height.md,tileMaxHeight*Theme.layout.overviewTileAspect,tileMaxHeight)
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
            // A calm, dimmed backdrop (the compositor also blurs the desktop behind it).
            Rectangle { anchors.fill:parent; color:Theme.color.overviewScrim }
            MouseArea { anchors.fill:parent; onClicked:overview.close() }
            Item { id: keys; focus:overview.open; Keys.onEscapePressed:overview.close() }
            // Workspace switcher: a compact pill at the top. Filled = the
            // active workspace, ring = the one shown below (All = every window).
            GlassSurface {
                id: strip
                anchors.horizontalCenter:parent.horizontalCenter
                y:Theme.space.xxxl
                width:Math.min(workspaceRow.width+Theme.space.sm*2,parent.width-Theme.space.xxxl*2)
                height:Theme.control.height.md+Theme.space.sm*2
                material:Theme.materials.panel
                Flickable {
                    anchors.fill:parent; anchors.margins:Theme.space.sm
                    contentWidth:workspaceRow.width; clip:true
                    Row {
                        id: workspaceRow
                        spacing:Theme.space.xs
                        component Chip: Rectangle {
                            id: chip
                            property string text: ""
                            property bool current: false
                            property bool active: false
                            property bool target: false
                            signal activated
                            width:Math.max(chipLabel.implicitWidth+Theme.space.lg*2,height)
                            height:Theme.control.height.md
                            radius:height/2
                            color:target ? Theme.color.accent : active ? Theme.color.text : chipMouse.containsMouse ? Theme.color.controlFill : "transparent"
                            border.width:current && !active ? Theme.border.focus : 0
                            border.color:Theme.color.text
                            BText { id: chipLabel; anchors.centerIn:parent; role:"label"; text:chip.text; font.bold:chip.active; color:chip.target ? Theme.color.onAccent : chip.active ? Theme.color.bg : Theme.color.text }
                            MouseArea { id: chipMouse; anchors.fill:parent; hoverEnabled:true; onClicked:chip.activated() }
                        }
                        Chip {
                            text:I18n.tr("All")
                            current:window.selected===null
                            onActivated:window.selected=null
                        }
                        // First after All, so it is seen however many workspaces follow.
                        Chip {
                            visible:window.minimizedCount>0
                            text:I18n.tr("Minimized · %1").arg(window.minimizedCount)
                            current:window.selected==="minimized"
                            onActivated:window.selected=window.selected==="minimized" ? null : "minimized"
                        }
                        Repeater {
                            id: workspaceRepeater
                            model:window.workspaces
                            delegate:Chip {
                                required property var modelData
                                text:modelData.name || String(modelData.id)
                                active:modelData.active===true
                                current:window.selected===modelData.id
                                target:window.dropWorkspace===modelData.id
                                opacity:modelData.monitor && modelData.monitor!==window.modelData.name ? Theme.opacity.disabled*2 : 1
                                onActivated:window.selected=window.selected===modelData.id ? null : modelData.id
                            }
                        }
                    }
                }
            }
            Item {
                id: area
                x:Theme.space.xxxl*2; y:strip.y+strip.height+Theme.space.xxxl
                width:parent.width-x*2; height:parent.height-y-Theme.space.xxxl*2
                BText { anchors.centerIn:parent; visible:window.wins.length===0; text:I18n.tr("No open windows"); role:"heading"; color:Theme.palette.silverBright }
                Repeater {
                    model:tiles
                    delegate:Item {
                        id: tile
                        required property string key
                        readonly property var win:window.wins.find(w=>String(w.id)===key)
                        readonly property var box:window.boxes.find(b=>b.key===key) || ({x:0,y:0,width:0,height:0})
                        readonly property var app:win ? Apps.forAppId(win.appId) : null
                        // Minimized: picture and title dimmed, a label on top.
                        readonly property real dim:win && win.minimized ? Theme.opacity.disabled : 1
                        readonly property bool hovered:mouse.containsMouse || window.dragged===key
                        property real offsetX:0
                        property real offsetY:0
                        x:box.x+offsetX; y:box.y+offsetY
                        width:box.width; height:box.height+Theme.control.height.md
                        z:window.dragged===key ? 10 : 0
                        visible:!!win
                        scale:hovered ? 1.03 : 1
                        Behavior on scale { BNumberAnimation {} }
                        Rectangle {
                            id: picture
                            width:parent.width; height:tile.box.height
                            radius:Theme.radius.md
                            color:Theme.color.controlFill
                            border.width:tile.hovered ? Theme.border.focus : Theme.border.hairline
                            border.color:tile.hovered ? Theme.color.accent : Theme.color.hairline
                            WindowCapture { id: capture; anchors.fill:parent; anchors.margins:parent.border.width; opacity:tile.dim; source:tile.win ? Compositor.captureSource(tile.win.id) : null; live:overview.open && tile.visible }
                            Image { anchors.centerIn:parent; width:Theme.icon.size.xl*2; height:width; source:tile.app ? tile.app.icon : ""; visible:!capture.hasContent }
                            Rectangle {
                                visible:!!tile.win && tile.win.minimized===true
                                anchors.centerIn:parent
                                width:minimizedBadge.implicitWidth+Theme.space.lg*2
                                height:Theme.control.height.md
                                radius:height/2
                                color:Theme.color.controlFill
                                Row {
                                    id: minimizedBadge
                                    anchors.centerIn:parent
                                    spacing:Theme.space.sm
                                    BIcon { anchors.verticalCenter:parent.verticalCenter; name:"arrow-up"; size:Theme.icon.size.sm; color:Theme.color.text }
                                    BText { anchors.verticalCenter:parent.verticalCenter; role:"label"; text:I18n.tr("Minimized · click to restore") }
                                }
                            }
                        }
                        // App icon and a short title, centred under the picture.
                        Row {
                            opacity:tile.dim
                            anchors.horizontalCenter:parent.horizontalCenter
                            y:tile.box.height; height:Theme.control.height.md
                            spacing:Theme.space.sm
                            Image { id: captionIcon; anchors.verticalCenter:parent.verticalCenter; width:Theme.icon.size.md; height:width; source:tile.app ? tile.app.icon : "" }
                            BText {
                                anchors.verticalCenter:parent.verticalCenter
                                width:Math.min(implicitWidth,tile.width-captionIcon.width-Theme.space.sm)
                                text:tile.win ? Layout.shortTitle(tile.win.title,tile.app ? tile.app.name : "") : ""
                                elide:Text.ElideRight; maximumLineCount:1; role:"label"
                                // On the dark backdrop in light and dark mode.
                                color:Theme.palette.silverBright
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill:parent; hoverEnabled:true; cursorShape:pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
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
