import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    readonly property var log: Log.scoped("OverviewWidget")
    required property var panelWindow
    required property bool overviewOpen
    signal dismissRequested()
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property real dpr: CompositorService.getScreenScale(panelWindow.screen)
    readonly property int workspacesShown: SettingsData.overviewRows * SettingsData.overviewColumns

    readonly property var allWorkspaces: Hyprland.workspaces?.values || []
    readonly property var allWorkspaceIds: {
        const workspaces = allWorkspaces;
        if (!workspaces || workspaces.length === 0)
            return [];
        try {
            const ids = workspaces.map(ws => ws?.id).filter(id => id !== null && id !== undefined);
            return ids.sort((a, b) => a - b);
        } catch (e) {
            return [];
        }
    }

    readonly property var thisMonitorWorkspaceIds: {
        const workspaces = allWorkspaces;
        const mon = monitor;
        if (!workspaces || workspaces.length === 0 || !mon)
            return [];
        try {
            const filtered = workspaces.filter(ws => ws?.monitor?.name === mon.name);
            return filtered.map(ws => ws?.id).filter(id => id !== null && id !== undefined).sort((a, b) => a - b);
        } catch (e) {
            return [];
        }
    }

    readonly property var displayedWorkspaceIds: {
        const ids = thisMonitorWorkspaceIds.filter(id => id > 0);
        const active = monitor?.activeWorkspace?.id ?? 1;
        if (active > 0 && !ids.includes(active)) ids.push(active);
        // Include one empty destination without enumerating gaps in workspace IDs.
        let next = 1;
        while (allWorkspaceIds.includes(next) || ids.includes(next)) next++;
        ids.push(next);
        return ids.sort((a, b) => a - b);
    }

    readonly property int minWorkspaceId: displayedWorkspaceIds.length > 0 ? displayedWorkspaceIds[0] : 1
    readonly property int maxWorkspaceId: displayedWorkspaceIds.length > 0 ? displayedWorkspaceIds[displayedWorkspaceIds.length - 1] : workspacesShown
    readonly property int displayWorkspaceCount: displayedWorkspaceIds.length

    property int previewWorkspaceId: monitor?.activeWorkspace?.id ?? 1

    readonly property int centerWorkspaceId: {
        const ids = displayedWorkspaceIds;
        if (!ids || ids.length === 0)
            return -1;
        const activeId = root.previewWorkspaceId;
        if (activeId !== undefined && activeId !== null && ids.includes(activeId))
            return activeId;
        return ids[0];
    }

    function getWorkspaceMonitorName(workspaceId) {
        if (!allWorkspaces || !workspaceId)
            return "";
        try {
            const ws = allWorkspaces.find(w => w?.id === workspaceId);
            return ws?.monitor?.name ?? "";
        } catch (e) {
            return "";
        }
    }

    function monitorIpcForWorkspace(workspaceId) {
        const workspace = allWorkspaces?.find(ws => ws?.id === workspaceId);
        return workspace?.monitor?.lastIpcObject ?? monitor?.lastIpcObject ?? null;
    }

    function monitorLogicalSize(ipc) {
        if (!ipc || !ipc.width || !ipc.height)
            return {
                "width": monitorPhysicalWidth,
                "height": monitorPhysicalHeight
            };

        const monScale = ipc.scale > 0 ? ipc.scale : 1;
        const rotated = ((ipc.transform ?? 0) % 2) === 1;
        return {
            "width": (rotated ? ipc.height : ipc.width) / monScale,
            "height": (rotated ? ipc.width : ipc.height) / monScale
        };
    }

    function cellForWorkspace(workspaceId) {
        const cell = gridLayout.cells.find(c => c.id === workspaceId);
        if (cell)
            return cell;
        return {
            "id": workspaceId,
            "x": 0,
            "y": 0,
            "width": workspaceImplicitWidth,
            "height": workspaceImplicitHeight
        };
    }

    function getWorkspaceViewportBounds(workspaceId, cellWidth, cellHeight) {
        const ipc = monitorIpcForWorkspace(workspaceId) ?? {};
        const logical = monitorLogicalSize(ipc);
        const reserved = ipc.reserved || [0, 0, 0, 0];

        const x = (ipc.x ?? 0) + (reserved[0] ?? 0);
        const y = (ipc.y ?? 0) + (reserved[1] ?? 0);
        const width = Math.max(logical.width - (reserved[0] ?? 0) - (reserved[2] ?? 0), 1);
        const height = Math.max(logical.height - (reserved[1] ?? 0) - (reserved[3] ?? 0), 1);

        return {
            "x": x,
            "y": y,
            "scale": Math.min(cellWidth / width, cellHeight / height)
        };
    }

    property bool monitorIsFocused: monitor?.focused ?? false
    property real scale: SettingsData.overviewScale
    property color activeBorderColor: Theme.primary

    readonly property real monitorPhysicalWidth: panelWindow.screen ? (panelWindow.screen.width / root.dpr) : (monitor?.width ?? 1920)
    readonly property real monitorPhysicalHeight: panelWindow.screen ? (panelWindow.screen.height / root.dpr) : (monitor?.height ?? 1080)
    property real workspaceImplicitWidth: monitorPhysicalWidth * root.scale
    property real workspaceImplicitHeight: monitorPhysicalHeight * root.scale

    property int workspaceZ: 0
    property int windowZ: 1
    property int monitorLabelZ: 2
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 28

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    readonly property real cardAspectRatio: monitorPhysicalHeight > 0 ? monitorPhysicalWidth / monitorPhysicalHeight : 16 / 9
    readonly property real cardBaseWidth: Math.min(monitorPhysicalWidth * 0.58, 1600)
    readonly property real cardBaseHeight: cardBaseWidth / cardAspectRatio

    function cardScaleForDistance(distance) { return 1; }

    // Single-row carousel: the active/focused workspace sits at its natural
    // size, centered, with neighbors shrinking and flowing out to the sides
    // (macOS-style wallpaper switcher) rather than wrapping into a grid.
    readonly property var gridLayout: {
        const ids = displayedWorkspaceIds;
        if (!ids || ids.length === 0)
            return {
                "cells": [],
                "width": 0,
                "height": 0,
                "centerX": 0
            };

        let centerIdx = ids.indexOf(centerWorkspaceId);
        if (centerIdx < 0)
            centerIdx = 0;

        const sizes = ids.map((id, i) => {
            const factor = cardScaleForDistance(Math.abs(i - centerIdx));
            return {
                "id": id,
                "width": cardBaseWidth * factor,
                "height": cardBaseHeight * factor
            };
        });

        const centers = new Array(ids.length);
        centers[centerIdx] = 0;
        let cursor = 0;
        for (let i = centerIdx - 1; i >= 0; i--) {
            cursor -= workspaceSpacing + sizes[i].width / 2 + sizes[i + 1].width / 2;
            centers[i] = cursor;
        }
        cursor = 0;
        for (let i = centerIdx + 1; i < ids.length; i++) {
            cursor += workspaceSpacing + sizes[i].width / 2 + sizes[i - 1].width / 2;
            centers[i] = cursor;
        }

        const maxHeight = sizes.reduce((acc, s) => Math.max(acc, s.height), 0);
        const rawCells = sizes.map((s, i) => ({
            "id": s.id,
            "x": centers[i] - s.width / 2,
            "y": (maxHeight - s.height) / 2,
            "width": s.width,
            "height": s.height
        }));

        const minX = rawCells.reduce((acc, c) => Math.min(acc, c.x), rawCells[0].x);
        const maxX = rawCells.reduce((acc, c) => Math.max(acc, c.x + c.width), rawCells[0].x + rawCells[0].width);

        const cells = rawCells.map(c => ({
            "id": c.id,
            "x": c.x - minX,
            "y": c.y,
            "width": c.width,
            "height": c.height
        }));

        return {
            "cells": cells,
            "width": maxX - minX,
            "height": maxHeight,
            "centerX": centers[centerIdx] - minX
        };
    }

    readonly property real carouselViewportCap: monitorPhysicalWidth * 0.90
    property real dragOffset: 0
    property bool trackingScroll: false
    readonly property real cardStep: cardBaseWidth + workspaceSpacing
    property real carouselOriginX: overviewBackground.width / 2 - gridLayout.centerX + dragOffset
    Behavior on carouselOriginX {
        enabled: !root.trackingScroll
        NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
    }
    readonly property real carouselOriginY: 82

    Timer {
        id: wheelCooldown
        interval: 140
        onTriggered: root.finishScroll()
    }

    function switchWorkspaceRelative(direction) {
        wheelCooldown.stop();
        root.trackingScroll = false;
        root.dragOffset = 0;
        const ids = root.displayedWorkspaceIds;
        const currentIndex = Math.max(0, ids.indexOf(root.centerWorkspaceId));
        const targetIndex = Math.max(0, Math.min(ids.length - 1, currentIndex + direction));
        if (targetIndex !== currentIndex)
            root.previewWorkspaceId = ids[targetIndex];
    }

    function finishScroll() {
        if (!root.trackingScroll) return;
        const offset = root.dragOffset;
        const direction = Math.abs(offset) >= root.cardStep * 0.16 ? (offset < 0 ? 1 : -1) : 0;
        root.switchWorkspaceRelative(direction);
    }

    function handleCarouselWheel(wheel) {
        wheel.accepted = true;
        if (root.draggingFromWorkspace !== -1) return;
        const pixels = wheel.pixelDelta;
        const hasPixels = pixels && (pixels.x !== 0 || pixels.y !== 0);
        const movement = hasPixels ? pixels : wheel.angleDelta;
        const delta = Math.abs(movement.x) > Math.abs(movement.y) ? movement.x : movement.y;
        if (!delta) return;
        root.trackingScroll = true;
        // Move on every scroll event instead of waiting for a threshold jump.
        const index = root.displayedWorkspaceIds.indexOf(root.centerWorkspaceId);
        let offset = root.dragOffset + delta * root.cardStep / (hasPixels ? 360 : 600);
        const first = index <= 0;
        const last = index >= root.displayedWorkspaceIds.length - 1;
        const limit = root.cardStep * ((first && offset > 0) || (last && offset < 0) ? 0.10 : 0.95);
        root.dragOffset = Math.max(-limit, Math.min(limit, offset));
        wheelCooldown.restart();
    }

    width: implicitWidth
    height: implicitHeight
    implicitWidth: overviewBackground.implicitWidth + Theme.spacingL * 2
    implicitHeight: overviewBackground.implicitHeight + Theme.spacingL * 2

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
    }

    onOverviewOpenChanged: {
        if (overviewOpen) {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
        }
    }

    Rectangle {
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        clip: true

        implicitWidth: Math.min(root.carouselViewportCap, workspaceGrid.implicitWidth) + padding * 2
        implicitHeight: workspaceGrid.implicitHeight + 170
        radius: Theme.cornerRadius
        // No enclosing "tray" panel: the carousel cards float directly over
        // the dimmed/blurred desktop (macOS-style), this Item only exists to
        // center and clip the row.
        color: "transparent"

        StyledText {
            x: 0; y: 4
            text: "Arbetsytor"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            color: Theme.surfaceText
        }
        StyledText {
            anchors.right: parent.right
            y: 14
            text: "Swipe to browse · Click to switch · Esc to close"
            font.pixelSize: 16
            color: Theme.withAlpha(Theme.surfaceText, 0.72)
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 10
            Repeater {
                model: root.displayedWorkspaceIds
                Rectangle {
                    required property var modelData
                    width: 36; height: 28; radius: 14
                    color: modelData === root.centerWorkspaceId ? Theme.primary : Theme.withAlpha(Theme.surfaceContainerHigh, 0.8)
                    StyledText {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.modelData === root.centerWorkspaceId ? Theme.surface : Theme.surfaceText
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.switchWorkspaceRelative(0);
                            root.previewWorkspaceId = parent.modelData;
                        }
                    }
                }
            }
        }

        Item {
            id: workspaceGrid

            z: root.workspaceZ
            x: root.carouselOriginX
            y: root.carouselOriginY
            implicitWidth: root.gridLayout.width
            implicitHeight: root.gridLayout.height

            Repeater {
                model: root.gridLayout.cells.length

                Rectangle {
                    id: workspace
                    required property int index
                    readonly property var cell: root.gridLayout.cells[index] ?? null
                    property int workspaceValue: cell?.id ?? -1
                    property bool workspaceExists: (root.allWorkspaceIds && workspaceValue > 0) ? root.allWorkspaceIds.includes(workspaceValue) : false
                    property var workspaceObj: (workspaceExists && Hyprland.workspaces?.values) ? Hyprland.workspaces.values.find(ws => ws?.id === workspaceValue) : null
                    property bool isOnThisMonitor: (workspaceObj && root.monitor) ? (workspaceObj.monitor?.name === root.monitor.name) : true
                    property bool isCenterCard: workspaceValue === root.centerWorkspaceId
                    property color defaultWorkspaceColor: workspaceExists ? Theme.surfaceContainerHigh : Theme.withAlpha(Theme.surfaceContainerHigh, 0.35)
                    property color hoveredWorkspaceColor: Qt.lighter(defaultWorkspaceColor, 1.1)
                    property color hoveredBorderColor: Theme.surfaceVariant
                    property bool hoveredWhileDragging: false

                    readonly property var cardSpringParams: Theme.springPreset("expressive", Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, root.overviewOpen))

                    SpringMotion {
                        id: xSpring
                        reducedMotion: Theme.springMotionDisabled
                        positionEpsilon: 0.05
                        velocityEpsilon: 0.05
                        stiffness: workspace.cardSpringParams.stiffness
                        damping: workspace.cardSpringParams.damping
                        value: workspace.cell?.x ?? 0
                    }

                    SpringMotion {
                        id: ySpring
                        reducedMotion: Theme.springMotionDisabled
                        positionEpsilon: 0.05
                        velocityEpsilon: 0.05
                        stiffness: workspace.cardSpringParams.stiffness
                        damping: workspace.cardSpringParams.damping
                        value: workspace.cell?.y ?? 0
                    }

                    SpringMotion {
                        id: widthSpring
                        reducedMotion: Theme.springMotionDisabled
                        positionEpsilon: 0.05
                        velocityEpsilon: 0.05
                        stiffness: workspace.cardSpringParams.stiffness
                        damping: workspace.cardSpringParams.damping
                        value: workspace.cell?.width ?? 0
                    }

                    SpringMotion {
                        id: heightSpring
                        reducedMotion: Theme.springMotionDisabled
                        positionEpsilon: 0.05
                        velocityEpsilon: 0.05
                        stiffness: workspace.cardSpringParams.stiffness
                        damping: workspace.cardSpringParams.damping
                        value: workspace.cell?.height ?? 0
                    }

                    onCellChanged: {
                        xSpring.retarget(cell?.x ?? 0);
                        ySpring.retarget(cell?.y ?? 0);
                        widthSpring.retarget(cell?.width ?? 0);
                        heightSpring.retarget(cell?.height ?? 0);
                    }

                    visible: workspaceValue !== -1

                    x: xSpring.value
                    y: ySpring.value
                    width: widthSpring.value
                    height: heightSpring.value
                    opacity: isOnThisMonitor ? 1 : 0.55
                    color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                    radius: Theme.cornerRadius
                    border.width: isCenterCard ? 2 : 1
                    border.color: hoveredWhileDragging ? hoveredBorderColor : (isCenterCard ? root.activeBorderColor : Theme.withAlpha(Theme.outlineVariant, 0.4))

                    ElevationShadow {
                        anchors.fill: parent
                        z: -1
                        level: Theme.elevationLevel1
                        fallbackOffset: workspace.isCenterCard ? 10 : 4
                        targetRadius: Theme.cornerRadius
                        targetColor: workspace.color
                        shadowOpacity: workspace.isCenterCard ? 0.4 : 0.18
                        shadowEnabled: Theme.elevationEnabled
                    }

                    ClippingRectangle {
                        id: wallpaperFrame
                        anchors.fill: parent
                        anchors.margins: workspace.border.width
                        radius: Math.max(0, workspace.radius - workspace.border.width)
                        readonly property string monitorName: root.getWorkspaceMonitorName(workspace.workspaceValue) || root.panelWindow.screen.name
                        readonly property string wallpaperPath: SessionData.getMonitorWallpaper(monitorName) || ""
                        color: wallpaperPath.startsWith("#") ? wallpaperPath : SettingsData.effectiveWallpaperBackgroundColor

                        Image {
                            anchors.fill: parent
                            readonly property string path: wallpaperFrame.wallpaperPath
                            source: !path || path.startsWith("#") ? "" : path.startsWith("file://") ? path : "file://" + path.split("/").map(segment => encodeURIComponent(segment)).join("/")
                            fillMode: Theme.getFillMode(SessionData.getMonitorWallpaperFillMode(wallpaperFrame.monitorName))
                            sourceSize: Qt.size(Math.round(workspace.width), Math.round(workspace.height))
                            asynchronous: true
                            smooth: true
                            cache: true
                        }
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: -30
                        text: "Skrivbord " + workspace.workspaceValue + (workspace.workspaceValue === root.monitor?.activeWorkspace?.id ? " · Aktivt" : workspace.workspaceExists ? "" : " · Nytt")
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.withAlpha(Theme.surfaceText, workspace.isCenterCard ? 1 : 0.65)
                    }

                    MouseArea {
                        id: workspaceArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (root.draggingTargetWorkspace === -1) {
                                HyprlandService.focusWorkspace(workspace.workspaceValue);
                                root.dismissRequested();
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            root.draggingTargetWorkspace = workspace.workspaceValue;
                            if (root.draggingFromWorkspace == root.draggingTargetWorkspace)
                                return;
                            workspace.hoveredWhileDragging = true;
                        }
                        onExited: {
                            workspace.hoveredWhileDragging = false;
                            if (root.draggingTargetWorkspace == workspace.workspaceValue)
                                root.draggingTargetWorkspace = -1;
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            x: root.carouselOriginX
            y: root.carouselOriginY
            implicitWidth: workspaceGrid.implicitWidth
            implicitHeight: workspaceGrid.implicitHeight

            Repeater {
                model: ScriptModel {
                    values: {
                        const workspaces = root.allWorkspaces;
                        const minId = root.minWorkspaceId;
                        const maxId = root.maxWorkspaceId;

                        if (!workspaces || workspaces.length === 0)
                            return [];

                        try {
                            const result = [];
                            for (const workspace of workspaces) {
                                const wsId = workspace?.id ?? -1;
                                if (root.displayedWorkspaceIds.includes(wsId)) {
                                    const toplevels = workspace?.toplevels?.values || [];
                                    for (const toplevel of toplevels) {
                                        result.push(toplevel);
                                    }
                                }
                            }
                            return result;
                        } catch (e) {
                            log.error("OverviewWidget filter error:", e);
                            return [];
                        }
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData

                    overviewOpen: root.overviewOpen
                    readonly property int windowWorkspaceId: modelData?.workspace?.id ?? -1
                    readonly property var workspaceCell: root.cellForWorkspace(windowWorkspaceId)
                    readonly property var workspaceBounds: root.getWorkspaceViewportBounds(windowWorkspaceId, workspaceCell.width, workspaceCell.height)

                    toplevel: modelData
                    scale: root.scale
                    monitorDpr: root.dpr
                    availableWorkspaceWidth: workspaceCell.width
                    availableWorkspaceHeight: workspaceCell.height
                    contentOriginX: workspaceBounds.x
                    contentOriginY: workspaceBounds.y
                    contentScale: workspaceBounds.scale
                    widgetMonitorId: root.monitor.id

                    xOffset: workspaceCell.x
                    yOffset: workspaceCell.y

                    z: atInitPosition ? root.windowZ : root.windowDraggingZ
                    property bool atInitPosition: (initX == x && initY == y)

                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: window.hovered = true
                        onExited: window.hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent

                        onPressed: mouse => {
                            root.draggingFromWorkspace = windowData?.workspace.id;
                            window.pressed = true;
                            window.Drag.active = true;
                            window.Drag.source = window;
                            window.Drag.hotSpot.x = mouse.x;
                            window.Drag.hotSpot.y = mouse.y;
                        }

                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace;
                            window.pressed = false;
                            window.Drag.active = false;
                            root.draggingFromWorkspace = -1;
                            root.draggingTargetWorkspace = -1;

                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                HyprlandService.moveToWorkspace(targetWorkspace, windowData?.address, false);
                                Qt.callLater(() => {
                                    Hyprland.refreshToplevels();
                                    Hyprland.refreshWorkspaces();
                                    Qt.callLater(() => {
                                        window.x = window.initX;
                                        window.y = window.initY;
                                    });
                                });
                            } else {
                                window.x = window.initX;
                                window.y = window.initY;
                            }
                        }

                        onClicked: event => {
                            if (!windowData || !windowData.address)
                                return;
                            if (event.button === Qt.LeftButton) {
                                HyprlandService.focusWindow(windowData.address);
                                root.dismissRequested();
                                event.accepted = true;
                            } else if (event.button === Qt.MiddleButton) {
                                HyprlandService.closeWindow(windowData.address);
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: monitorLabelSpace
            x: root.carouselOriginX
            y: root.carouselOriginY
            implicitWidth: workspaceGrid.implicitWidth
            implicitHeight: workspaceGrid.implicitHeight
            z: root.monitorLabelZ

            Repeater {
                model: root.gridLayout.cells.length
                delegate: Item {
                    id: labelItem
                    required property int index
                    readonly property var cell: root.gridLayout.cells[index] ?? null
                    property int workspaceValue: cell?.id ?? -1
                    property bool workspaceExists: (root.allWorkspaceIds && workspaceValue > 0) ? root.allWorkspaceIds.includes(workspaceValue) : false
                    property string workspaceMonitorName: (workspaceValue > 0) ? root.getWorkspaceMonitorName(workspaceValue) : ""

                    x: cell?.x ?? 0
                    y: cell?.y ?? 0
                    width: cell?.width ?? 0
                    height: cell?.height ?? 0

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingS
                        width: monitorNameText.contentWidth + Theme.spacingS * 2
                        height: monitorNameText.contentHeight + Theme.spacingXS * 2
                        radius: Theme.cornerRadius
                        color: Theme.surface
                        visible: Quickshell.screens.length > 1 && labelItem.workspaceExists && labelItem.workspaceMonitorName !== ""

                        StyledText {
                            id: monitorNameText
                            anchors.centerIn: parent
                            text: labelItem.workspaceMonitorName
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
