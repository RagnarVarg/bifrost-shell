import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compositor
import qs.Core
import qs.Components.Glass
import qs.Components.Motion
import qs.Modules
import qs.Modules.Launcher
import "../../Shared/GlassJoin.js" as GlassJoin

// The bar on one screen. Styles: floating (margin + radius), attached (edge
// to edge, square), with a full, faint or no panel glass and widgets either
// integrated, boxed (a glass bubble each) or grouped (a bubble per zone).
//
// Auto-hide (bar.autohide.*): one MouseArea spans the whole band (edge margin
// + bar) with the widgets inside, so hover is continuous; the shared AutoHide
// controller decides. Space is reserved only while the bar is shown, so tiled
// windows use the full screen when it is hidden and make room when it slides
// in; "smart" keeps it shown on workspaces without windows.
//
// Menus (BarMenu) are drawn inside this window by MenuHost, as part of the
// glass they open from; the window grows toward the screen while one is open.
//
// Edges: a top or bottom bar is laid out directly. A side bar is the same bar
// turned 90° clockwise (`view`): left = the bottom layout, right = the top
// layout, so menus, autohide and the frame need no code of their own. Widgets
// (WidgetHost) and menu contents (BarMenu) are turned back and lay themselves
// out upright (`vertical`). Everything in `view` is in these unturned "bar
// coordinates"; windowRect() maps an item back to the window.
PanelWindow {
    id: root

    required property var modelData

    readonly property var cfg: Config.values.bar
    readonly property string edge: ["top", "bottom", "left", "right"].indexOf(cfg.position) >= 0 ? cfg.position : "top"
    readonly property bool vertical: edge === "left" || edge === "right"
    // The layout the band uses (see above): a left bar is laid out as a bottom bar.
    readonly property bool atBottom: edge === "bottom" || edge === "left"
    readonly property string style: cfg.style
    // Panel background (full, faint, none) and widget style (integrated,
    // boxed = a bubble per widget, grouped = a bubble per zone).
    readonly property string background: cfg.background || "panel"
    readonly property string widgetStyle: cfg.widgetStyle || "integrated"
    // Frame: the bar is one side of a glass frame around the whole screen.
    readonly property bool frame: Metrics.frame
    readonly property real frameThickness: Metrics.frameThickness
    readonly property bool panel: frame || background !== "none"
    readonly property bool islands: widgetStyle === "grouped"
    readonly property bool bubbles: widgetStyle === "boxed"
    // Separate glass shapes take input and host menus only without a panel.
    readonly property bool shapesOnly: !panel && (islands || bubbles)
    readonly property real margin: Metrics.barMargin
    readonly property real barHeight: Metrics.barHeight
    readonly property var material: {
        const m = Object.assign({}, Theme.materials.bar);
        if (style === "attached" && !frame)
            m.radius = 0;
        return m;
    }
    // Faint panel: a hint of the bar glass, no shadow.
    readonly property var panelMaterial: background !== "subtle" ? material : Object.assign({}, material, {
            fill: Qt.alpha(material.tint, material.opacity * 0.28),
            elevation: { blur: 0, y: 0, spread: 0, opacity: 0 },
            depth: material.depth * 0.3,
            density: 0,
            bevelStrength: 0
        })
    // Bubbles and islands on top of a panel are glass within glass: lighter
    // and without their own shadow; without a panel they are the bar glass.
    readonly property var shapeMaterial: !panel ? Object.assign({}, material, {
            radius: Math.min(material.radius, barHeight / 2),
            // Neighbouring bubbles are close: a short, centred shadow keeps
            // the gaps between them clean.
            elevation: bubbles ? { blur: (material.elevation.blur || 0) * 0.5, y: 0, spread: 0, opacity: (material.elevation.opacity || 0) * 0.6 } : material.elevation
        }) : Object.assign({}, material, {
            radius: Math.min(material.radius, barHeight / 2),
            fill: Qt.alpha(material.tint, material.opacity * 0.45),
            elevation: { blur: 0, y: 0, spread: 0, opacity: 0 },
            depth: material.depth * 0.5,
            density: 0
        })
    readonly property real shapeInset: panel ? Theme.space.xs : 0
    readonly property real shadowRoom: Math.max((material.elevation.opacity || 0) > 0 ? material.elevation.blur + Math.abs(material.elevation.y) : 0, (material.glow || 0) > 0 ? Theme.space.xl * 2 : 0)
    readonly property var widgets: cfg.widgets || ({})
    // Input must end at the reserved/client boundary. Extra room for
    // shadows belongs to the window, never to its interactive band.
    readonly property real bandHeight: margin + barHeight

    readonly property alias menuHost: menuHost
    readonly property bool revealed: autoHide.revealed
    // Diagnostics (IPC bar.status)
    readonly property var hoverState: ({ launcherHosting: launcherMenu.hosting, launcherRequested: ShellState.launcherOpen, launcherScreen: ShellState.launcherScreen, launcherMenuOpen: launcherMenu.isOpen, pointer: band.containsMouse || edgeCatch.containsMouse, covered: autoHide.covered, revealed: autoHide.revealed, want: autoHide.wantReveal, menu: menuHost.menu !== null, menuPointer: menuHost.pointerInside, menuHoverSeen: menuHost.hoverSeen, menuArea: menuHost.area.containsMouse, menuAnchor: menuHost.anchorHovered })

    // Monitor-local rects of the shown widgets (IPC bar.widgets; hover tests).
    function widgetRects(): var {
        const out = [];
        for (const z of [left, center, right])
            for (const h of z.hosts())
                out.push(Object.assign({ id: h.entry.id }, menuHost.screenRect(h, 0, 0, h.width, h.height)));
        return out;
    }

    AutoHide {
        id: autoHide

        enabled: root.cfg.autohide.enabled && !root.frame
        smart: root.cfg.autohide.smart
        pointerInside: band.containsMouse || edgeCatch.containsMouse
        pinned: root.cfg.autohide.pinWhilePopupOpen && (menuHost.menu !== null || ShellState.anyPanelOpen(root.modelData.name))
        screenName: root.modelData.name
        area: root.edge === "left" ? { x: 0, y: 0, width: root.bandHeight, height: root.modelData.height } : root.edge === "right" ? { x: root.modelData.width - root.bandHeight, y: 0, width: root.bandHeight, height: root.modelData.height } : { x: 0, y: root.atBottom ? root.modelData.height - root.bandHeight : 0, width: root.modelData.width, height: root.bandHeight }
        delayMs: root.cfg.autohide.delayMs
        tiledCovers: true
    }

    Component.onCompleted: ShellState.registerBar(root)
    Component.onDestruction: ShellState.unregisterBar(root)

    screen: modelData
    WlrLayershell.namespace: RunMode.layerNamespace("bar")
    WlrLayershell.layer: WlrLayer.Top
    // MenuHost owns the focus grab; Exclusive conflicts with that grab on Hyprland.
    WlrLayershell.keyboardFocus: menuHost.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"

    // A frame covers the whole screen (input only on the frame itself); its
    // space is reserved by FrameReserve windows, as a surface anchored to all
    // four edges can't reserve any.
    anchors.top: edge !== "bottom" || frame
    anchors.bottom: edge !== "top" || frame
    anchors.left: edge !== "right" || frame
    anchors.right: edge !== "left" || frame

    // Thickness toward the screen (height of a top/bottom bar, width of a side bar).
    readonly property real thickness: bandHeight + shadowRoom + (menuHost.room > 0 ? menuHost.room + shadowRoom : 0)
    implicitHeight: thickness
    implicitWidth: thickness
    // The bar reserves its space whenever it is shown, also when auto-hiding:
    // tiled windows shrink as it slides in and grow back when it hides.
    // Assigning exclusiveZone switches Quickshell to ExclusionMode.Normal, so
    // "no reservation" must be a zone of 0, not just ExclusionMode.Ignore.
    // A frame takes -1: it covers the whole screen, the FrameReserve zones
    // included, where 0 would place it inside them (inset by its own frame).
    readonly property bool reserve: RunMode.reservesScreenSpace && !frame && (!cfg.autohide.enabled || revealed)
    exclusionMode: reserve ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: reserve ? barHeight + margin : frame ? -1 : 0

    // Input: the edge strip while hidden; while shown, the whole band when
    // auto-hiding (continuous hover), otherwise just the glass or each island
    // so margins and island gaps stay click-through.
    mask: Region {
        MaskRect {
            source: !root.revealed ? revealStrip : root.frame ? band : root.shapesOnly ? null : root.cfg.autohide.enabled ? band : content
        }

        MaskRect {
            source: root.revealed && root.shapesOnly ? shapes : null
        }

        MaskRect {
            source: root.revealed && root.shapesOnly && root.cfg.autohide.enabled ? revealStrip : null
        }

        MaskRect {
            source: root.revealed && menuHost.area.visible ? menuHost.area : null
        }
    }

    // Window rect of (a part of) an item inside `view`. Region { item } can't
    // be used: it maps only the item's origin and far corner, which a turned
    // view swaps.
    function windowRect(item, x, y, w, h) {
        const a = item.mapToItem(null, x || 0, y || 0);
        const b = item.mapToItem(null, (x || 0) + (w === undefined ? item.width : w), (y || 0) + (h === undefined ? item.height : h));
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }

    // Input region for one item; re-evaluated when the item or the parts of
    // the bar it sits in move.
    component MaskRect: Region {
        property Item source: null
        readonly property rect r: {
            void [root.width, root.height, root.vertical, band.y, band.height, content.x, content.y, content.width, content.height, menuHost.shapeX, menuHost.shapeWidth, menuHost.shapeHeight, root.revealed];
            const i = source;
            if (!i)
                return Qt.rect(0, 0, 0, 0);
            void [i.x, i.y, i.width, i.height];
            return root.windowRect(i);
        }

        x: Math.floor(r.x)
        y: Math.floor(r.y)
        width: Math.ceil(r.width)
        height: Math.ceil(r.height)
    }

    // The band in bar coordinates, turned for a side bar (see the top).
    Item {
        id: view

        width: root.vertical ? root.height : root.width
        height: root.vertical ? root.width : root.height
        transform: [
            Rotation {
                angle: root.vertical ? 90 : 0
            },
            Translate {
                x: root.vertical ? root.width : 0
            }
        ]

        MouseArea {
            id: band

            width: parent.width
            height: root.bandHeight
            y: root.atBottom ? parent.height - height : 0
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            // The far edge of a bottom-layout band is exclusive for hover; a
            // left bar is that layout turned, so the pointer resting on the
            // screen edge (x = 0) lands exactly there. This strip reaches one
            // pixel past it.
            MouseArea {
                id: edgeCatch

                visible: root.atBottom
                y: parent.height - 1
                width: parent.width
                height: 2
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Item {
                id: revealStrip

                width: parent.width
                height: Theme.space.xs
                y: root.atBottom ? parent.height - height : 0
            }

            Item {
                id: content

                readonly property real hiddenOffset: (root.bandHeight + root.shadowRoom) * (root.atBottom ? 1 : -1)

                // bar.width: a share of the edge, centred, never narrower
                // than the widgets need. A frame always spans the edge.
                readonly property real fullWidth: band.width - (root.frame ? root.frameThickness : root.margin) * 2
                readonly property real neededWidth: left.width + center.width + right.width + Theme.space.sm * 2 + Theme.space.xl * 2
                x: (band.width - width) / 2
                y: root.atBottom ? band.height - root.margin - root.barHeight : root.margin
                width: root.frame ? fullWidth : Math.min(fullWidth, Math.max(fullWidth * Metrics.barWidth, neededWidth))
                height: root.barHeight

                transform: Translate {
                    y: root.revealed ? 0 : content.hiddenOffset

                    Behavior on y {
                        BNumberAnimation {
                            speed: "normal"
                            curve: "emphasized"
                        }
                    }
                }

                WheelHandler {
                    enabled: Config.values.workspaces.scroll && Compositor.supports("focusWorkspace")
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: e => Compositor.focusRelativeWorkspace(e.angleDelta.y < 0 || e.angleDelta.x < 0 ? 1 : -1, Config.values.workspaces.perMonitor ? root.modelData.name : "", Config.values.workspaces.persistent)
                }

                // Frame: one glass for the whole screen minus a rounded hole, placed
                // in content coordinates so menus grow out of its bar side.
                GlassSurface {
                    id: frameGlass

                    visible: root.frame
                    x: -content.x
                    y: -(band.y + content.y)
                    width: view.width
                    height: view.height
                    material: Object.assign({}, root.panelMaterial, { radius: 0 })
                    hole: root.atBottom ? Qt.rect(root.frameThickness, root.frameThickness, width - root.frameThickness * 2, height - root.frameThickness - root.barHeight) : Qt.rect(root.frameThickness, root.barHeight, width - root.frameThickness * 2, height - root.frameThickness - root.barHeight)
                    holeRadius: Theme.windowRadius
                    stripY: root.atBottom ? height - root.barHeight : 0
                    stripHeight: root.barHeight
                    attachment: menuHost.attachmentFor(frameGlass)
                    readonly property var dockWindow: ShellState.dockWindows.find(w => w.modelData.name === root.modelData.name) || null
                    function dockJoin(a) {
                        return GlassJoin.transform(a, (x,y) => frameGlass.mapFromItem(null,x,y));
                    }
                    attachment2: dockWindow ? dockJoin(dockWindow.frameAttachment) : null
                    attachment3: dockWindow ? dockJoin(dockWindow.framePanelAttachment) : null
                }

                // The panel glass (floating / attached; full or faint)
                GlassSurface {
                    id: barGlass

                    anchors.fill: parent
                    visible: root.panel && !root.frame
                    material: root.panelMaterial
                    attachment: menuHost.attachmentFor(barGlass)
                }

                // Grouped: one glass per non-empty zone. Boxed: one per widget.
                // Without a panel they are the bar and menus grow out of them.
                component Shape: GlassSurface {
                    id: shape

                    property real sx: 0
                    property real sw: 0

                    attachment: menuHost.attachmentFor(shape)
                    x: sx
                    y: root.shapeInset
                    width: sw
                    height: root.barHeight - root.shapeInset * 2
                    material: root.shapeMaterial
                }

                Item {
                    id: shapes

                    anchors.fill: parent
                    readonly property var zones: [left, center, right]
                    readonly property var all: {
                        void [islandRepeater.model, bubbleLeft.model, bubbleCenter.model, bubbleRight.model];
                        const out = [];
                        for (const r of [islandRepeater, bubbleLeft, bubbleCenter, bubbleRight])
                            for (let i = 0; i < r.count; i++)
                                if (r.itemAt(i))
                                    out.push(r.itemAt(i));
                        return out;
                    }

                    Repeater {
                        id: islandRepeater

                        model: root.islands ? shapes.zones.filter(z => z.width > 0 && z.entries.length > 0) : []

                        delegate: Shape {
                            required property var modelData

                            sx: modelData.x - Theme.space.sm
                            sw: modelData.width + Theme.space.sm * 2
                        }
                    }

                    component Bubbles: Repeater {
                        property Item zone: null

                        model: root.bubbles && zone ? zone.bubbles.map(b => ({ x: zone.x + b.x, width: b.width })) : []

                        delegate: Shape {
                            required property var modelData

                            sx: modelData.x
                            sw: modelData.width
                        }
                    }

                    Bubbles {
                        id: bubbleLeft

                        zone: left
                    }

                    Bubbles {
                        id: bubbleCenter

                        zone: center
                    }

                    Bubbles {
                        id: bubbleRight

                        zone: right
                    }
                }

                BarZone {
                    id: left

                    x: Theme.space.sm
                    height: parent.height - Theme.space.xs * 2
                    anchors.verticalCenter: parent.verticalCenter
                    entries: root.widgets.left || []
                    bar: root
                }

                BarZone {
                    id: center

                    anchors.centerIn: parent
                    height: parent.height - Theme.space.xs * 2
                    entries: root.widgets.center || []
                    bar: root
                }

                BarZone {
                    id: right

                    x: parent.width - width - Theme.space.sm
                    height: parent.height - Theme.space.xs * 2
                    anchors.verticalCenter: parent.verticalCenter
                    entries: root.widgets.right || []
                    bar: root
                }

                // A panel placement does not require a visible launcher widget.
                // This anchor uses the same MenuHost/GlassJoin as button menus.
                Item {
                    id: launcherAnchor
                    anchors.centerIn: parent
                    width: root.barHeight
                    height: root.barHeight
                }

                PanelMenu {
                    id: launcherMenu
                    panel: "launcher"
                    bar: root
                    anchorItem: launcherAnchor
                    hosting: Config.values.launcher.placement === "bar" && !["left", "center", "right"].some(zone => (root.widgets[zone] || []).some(entry => entry.id === "launcher"))
                    panelOpen: hosting && ShellState.launcherOpen && ShellState.launcherScreen === root.modelData.name
                    openOnHover: false
                    exclusiveKeyboard: true
                    centerOnScreen: true
                    onOpenRequested: ShellState.openLauncher(root.modelData.name)
                    onCloseRequested: ShellState.launcherOpen = false

                    LauncherContent {
                        active: launcherMenu.isOpen
                        width: Math.min(implicitWidth, root.modelData.width - Theme.space.xxxl * 2)
                        height: implicitHeight
                        maxHeight: root.modelData.height - Metrics.edgeSpace("top") - Metrics.edgeSpace("bottom") - Theme.space.xxxl
                    }
                }

                MenuHost {
                    id: menuHost

                    anchors.fill: parent
                    bar: root
                    band: band
                    // Menus grow out of the panel, else out of the island or
                    // bubble they open from; with neither they float (MenuHost).
                    glasses: root.frame ? [frameGlass] : root.panel ? [barGlass] : shapes.all
                }
            }
        }
    }
}
