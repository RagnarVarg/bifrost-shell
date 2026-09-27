import QtQuick
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Motion
import qs.Components.Popup
import qs.Components.State
import qs.Components.Text
import qs.Services
import qs.Modules
import qs.Components.Glass
import qs.Components.Icons

// One dock entry. pinned-only: icon; running: dots; active: prism + accent bar.
// Hover lifts the icon slightly; previews only open for apps with windows.
Item {
    id: dockItem

    property var model: null    // { key, app, pinned, windows }
    property string screenName: ""
    property string edge: "bottom"
    readonly property var hoverConfig: Config.values.dock.hover || ({})
    readonly property bool isOverview: model && model.kind === "overview"
    readonly property bool special: isTrash || isLauncher || isOverview
    readonly property string specialIcon: isTrash ? Platform.iconPath("user-trash", "user-trash-symbolic")
        : isOverview ? "file://" + Paths.assetsDir + "/icons/overview.svg"
        : isLauncher ? "file://" + Paths.assetsDir + "/icons/app-launcher.svg" : ""
    property bool labelOpen: false
    readonly property bool isTrash: model && model.kind === "trash"
    readonly property bool isLauncher: model && model.kind === "launcher"
    property real iconSize: Metrics.dockIconSize
    readonly property int windowCount: model ? model.windows.length : 0
    readonly property bool running: windowCount > 0
    readonly property bool hovered: mouse.containsMouse
    readonly property bool previewEnabled: running && !isLauncher && Config.values.dock.preview !== false
    signal labelRequested(var item)
    signal previewRequested(var item)
    signal previewDismissed
    onPreviewEnabledChanged: if (!previewEnabled) {
        tipTimer.stop();
        previewDismissed();
    }
    readonly property bool isActive: running && Compositor.activeWindow !== null && model.windows.some(w => w.id === Compositor.activeWindow.id)
    readonly property string name: isOverview ? I18n.tr("Window overview") : isTrash ? I18n.tr("Trash") : isLauncher ? I18n.tr("Launcher") : model && model.app ? model.app.name : (model ? model.key.replace("window:", "") : "")

    property bool dragging: false
    signal reorderMoved(var item, real x, real y)
    signal reorderEnded(bool commit)
    signal contextMenu

    width: iconSize + Theme.space.sm * 2
    height: iconSize + Theme.space.sm * 2

    function activate() {
        if (!model)
            return;
        if (isOverview) { ShellState.toggleOverview(); return; }
        if (isTrash) { Platform.execDetached(["xdg-open", "trash:///"]); return; }
        if (isLauncher) { ShellState.toggleLauncher(screenName); return; }
        if (!running) {
            Apps.launch(model.app);
            return;
        }
        // Focus the app; when it is already active, cycle its windows. All
        // minimized: the last minimized one comes back.
        Compositor.activateAppWindows(model.windows);
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.radius.md
        hovered: mouse.containsMouse && dockItem.hoverConfig.highlight !== false
        pressed: mouse.pressed
        active: dockItem.isActive
    }

    Item {
        id: artwork
        width:dockItem.iconSize;height:width
        readonly property real lift: mouse.containsMouse && !dockItem.dragging ? Metrics.gap(dockItem.hoverConfig.lift === undefined ? 2 : dockItem.hoverConfig.lift) : 0
        x:Theme.space.sm+(dockItem.edge==="left" ? lift : dockItem.edge==="right" ? -lift : 0)
        y:Theme.space.sm+(dockItem.edge==="top" ? lift : dockItem.edge==="bottom" ? -lift : 0)
        scale:mouse.containsMouse && !dockItem.dragging ? (dockItem.hoverConfig.scale || 1.15) : 1
        Behavior on x { BNumberAnimation {} }
        Behavior on y { BNumberAnimation {} }
        Behavior on scale { BNumberAnimation {} }
        Image {
            id: themedArtwork
            anchors.fill:parent
            source:dockItem.special ? dockItem.specialIcon : dockItem.model && dockItem.model.app ? dockItem.model.app.icon : Platform.iconPath(dockItem.name.toLowerCase(),"application-x-executable")
            fillMode:Image.PreserveAspectFit
            sourceSize:Qt.size(width*2,height*2)
            smooth:true
        }
        BIcon {
            anchors.fill:parent
            visible:dockItem.special && themedArtwork.status === Image.Error
            name:dockItem.isTrash ? "trash" : dockItem.isOverview ? "windows" : "apps"
            size:dockItem.iconSize
        }
    }

    // Running / active indicator
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.xxs
        spacing: Theme.space.xxs
        visible: dockItem.running

        Repeater {
            model: dockItem.isActive ? 1 : Math.min(3, dockItem.windowCount)

            delegate: Rectangle {
                width: dockItem.isActive ? Theme.space.lg : Theme.space.xs
                height: Theme.space.xxs + 1
                radius: height / 2
                color: dockItem.isActive ? Theme.color.accent : Theme.color.textMuted

                Behavior on width {
                    BNumberAnimation {}
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: dockItem.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property point pressPoint
        property bool dragged: false
        onPressed: m => { dockItem.labelOpen=false; tipTimer.stop(); pressPoint=Qt.point(m.x,m.y); dragged=false; }
        onPositionChanged: m => {
            if (!(pressedButtons & Qt.LeftButton)) return;
            if (!dragged && Math.hypot(m.x-pressPoint.x,m.y-pressPoint.y) < Theme.space.sm) return;
            dragged=true; dockItem.dragging=true;
            tipTimer.stop(); dockItem.previewDismissed();
            dockItem.reorderMoved(dockItem,m.x,m.y);
        }
        onReleased: { if (dragged) dockItem.reorderEnded(true); dockItem.dragging=false; }
        onCanceled: { if (dragged) dockItem.reorderEnded(false); dockItem.dragging=false; }
        onClicked: m => {
            if (dragged) return;
            tipTimer.stop(); dockItem.previewDismissed();
            if (m.button === Qt.RightButton)
                dockItem.contextMenu();
            else if (m.button === Qt.MiddleButton && !dockItem.special)
                Apps.launch(dockItem.model.app);
            else
                dockItem.activate();
        }
        onContainsMouseChanged: {
            dockItem.labelOpen=false;
            if (containsMouse && !pressed && (dockItem.previewEnabled || dockItem.hoverConfig.names !== false)) tipTimer.restart();
            else tipTimer.stop();
        }
    }

    Timer {
        id: tipTimer

        interval: dockItem.hoverConfig.delay === undefined ? 500 : dockItem.hoverConfig.delay
        onTriggered: if (!mouse.pressed && !dockItem.dragging && mouse.containsMouse) {
            if (dockItem.previewEnabled) dockItem.previewRequested(dockItem);
            else if (dockItem.hoverConfig.names !== false) {dockItem.labelOpen=true;dockItem.labelRequested(dockItem);}
        }
    }

}
