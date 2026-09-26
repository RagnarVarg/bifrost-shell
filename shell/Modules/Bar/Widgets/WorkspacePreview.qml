import QtQuick
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.State
import qs.Components.Text
import qs.Modules.Bar
import qs.Services
import "../../../Shared/WorkspaceMap.js" as WorkspaceMap

// Preview of a workspace, opened by hovering its pill (workspaces.preview):
// the monitor as a small map – its wallpaper (Services/Wallpapers, filled as
// on the desktop) with every window where it is, as a live picture
// (Compat/WindowCapture, workspaces.previewLive). A window's app icon shows
// only when no picture can be had. A click on a window focuses it. A BarMenu
// like the others: it grows out of the bar and closes when the pointer leaves
// it and the workspaces.
//
// Stable while open: the tiles are a ListModel kept in line by window id
// (WorkspaceMap.sync), so geometry polls move tiles instead of rebuilding
// them, and each picture keeps its last frame while hidden or while the next
// one is on its way. Tiles exist for every window on the monitor, those of
// other workspaces hidden, so switching the previewed workspace shows their
// last pictures at once.
BarMenu {
    id: menu

    property var workspace: null            // the hovered pill's entry
    property string monitorName: ""
    readonly property var mon: Compositor.monitors.find(m => m.name === monitorName) || null
    readonly property var wins: workspace ? Compositor.windows.filter(w => w.workspaceId === workspace.id) : []
    readonly property bool live: Config.values.workspaces.previewLive !== false && Compositor.supports("windowCapture")
    // Every window on this monitor, for the tiles (see above).
    readonly property var monitorWins: Compositor.windows.filter(w => w.monitor === monitorName)
    readonly property var map: WorkspaceMap.layout(mon, monitorWins, Theme.layout.workspacePreviewWidth)
    readonly property bool activeWorkspace: workspace && workspace.active === true
    readonly property string workspaceKey: workspace ? String(workspace.id) : ""
    readonly property var winById: {
        const m = {};
        for (const w of monitorWins)
            m[String(w.id)] = w;
        return m;
    }

    onMapChanged: WorkspaceMap.sync(tiles, map.windows)
    Component.onCompleted: WorkspaceMap.sync(tiles, map.windows)

    ListModel {
        id: tiles
    }

    // Hover details: no focus grab, closes on leave.
    grabFocus: false
    openOnHover: Config.values.workspaces.preview === true && Compositor.supports("windowList")
    padding: Theme.space.md

    onIsOpenChanged: isOpen ? Compositor.retainGeometry() : Compositor.releaseGeometry()

    Column {
        width: menu.map.width
        spacing: Theme.space.md

        Item {
            width: parent.width
            height: Math.max(workspaceLabel.implicitHeight, windowCount.implicitHeight)
            BText {
                id: workspaceLabel
                width: parent.width - windowCount.width - Theme.space.md
                text: menu.workspace ? I18n.tr("Workspace %1").arg(menu.workspace.name || menu.workspace.id) : ""
                role: "label"
                tone: menu.activeWorkspace ? "accent" : "primary"
                elide: Text.ElideRight
            }
            BText {
                id: windowCount
                anchors.right: parent.right
                text: menu.wins.length === 0 ? I18n.tr("Empty") : I18n.tr("%n window(s)", menu.wins.length)
                role: "caption"
                tone: "muted"
            }
        }

        // The monitor, scaled: its wallpaper, then the windows.
        Rectangle {
            width: menu.map.width
            height: menu.map.height
            radius: Theme.radius.md
            color: Theme.color.controlFill
            border.width: menu.activeWorkspace ? Theme.border.focus : Theme.border.hairline
            border.color: menu.activeWorkspace ? Theme.color.accent : Theme.color.hairline
            clip: true

            Rectangle {
                anchors.fill: parent
                z: 1000
                color: "transparent"
                radius: parent.radius
                border.width: parent.border.width
                border.color: parent.border.color
            }

            Image {
                anchors.fill: parent
                anchors.margins: Theme.border.hairline
                source: Wallpapers.sourceFor(menu.monitorName)
                fillMode: Wallpapers.fillMode
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
                cache: true
                smooth: true
            }

            Repeater {
                model: tiles

                delegate: Item {
                    id: tile

                    required property string winId
                    required property string ws
                    required property real tx
                    required property real ty
                    required property real tw
                    required property real th
                    required property int order
                    readonly property var win: menu.winById[winId] || null
                    readonly property var captureSource: menu.live ? Compositor.captureSource(winId) : null
                    // Once a picture has come, the tile never falls back to
                    // the icon; before that, only after a grace period.
                    property bool pictured: false
                    property bool gaveUp: false
                    readonly property bool showIcon: !menu.live || captureSource === null || (!pictured && gaveUp)
                    readonly property bool current: ws === menu.workspaceKey

                    x: tx
                    y: ty
                    width: tw
                    height: th
                    z: order
                    visible: current

                    onCaptureSourceChanged: {
                        pictured = false;
                        gaveUp = false;
                    }

                    Timer {
                        interval: Theme.motion.duration.slow * 2
                        running: menu.isOpen && tile.current && tile.captureSource !== null && !tile.pictured && !tile.gaveUp
                        onTriggered: tile.gaveUp = true
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.border.hairline
                        radius: Theme.radius.sm
                        color: tile.showIcon ? Theme.color.surfaceRaised : "transparent"
                        border.width: Theme.border.hairline
                        border.color: tile.win && tile.win.focused ? Theme.color.accent : Theme.color.hairline
                        clip: true

                        WindowCapture {
                            id: capture

                            anchors.fill: parent
                            anchors.margins: Theme.border.hairline
                            visible: tile.captureSource !== null
                            live: menu.isOpen
                            source: tile.captureSource
                            onHasContentChanged: if (hasContent)
                                tile.pictured = true
                        }

                        // App icon (and title), only without a picture.
                        Column {
                            visible: tile.showIcon
                            anchors.centerIn: parent
                            width: parent.width - Theme.space.sm * 2
                            spacing: Theme.space.xxs

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                readonly property var app: tile.win ? Apps.forAppId(tile.win.appId) : null
                                width: Math.min(Theme.icon.size.lg, tile.height * 0.5)
                                height: width
                                sourceSize: Qt.size(width * 2, height * 2)
                                source: app ? app.icon : Platform.iconPath(((tile.win && tile.win.appId) || "").toLowerCase(), "application-x-executable")
                            }

                            BText {
                                visible: tile.height > Theme.icon.size.lg * 2 && tile.width > Theme.icon.size.lg * 3
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.win ? (tile.win.title || tile.win.appId) : ""
                                role: "caption"
                                tone: "muted"
                                elide: Text.ElideRight
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: Theme.radius.sm
                            hovered: tileMouse.containsMouse
                            pressed: tileMouse.pressed
                        }
                    }

                    MouseArea {
                        id: tileMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Compositor.focusWindow(tile.winId);
                            menu.close();
                        }
                    }
                }
            }
        }
    }
}
