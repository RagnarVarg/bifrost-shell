import Quickshell
import Quickshell.Io
import QtQuick
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    // ---- Settings ----
    property int speed: 5000
    property int animDuration: 1000
    property real zoomScale: 1.0
    property real edgeScale: 0.40
    property real skewFactor: 0
    property int baseSpacing: 10
    property int startPosition: 20

    // Resolved once, used to expand relative paths from config.json
    readonly property string homeDir: Quickshell.env("HOME")

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted:
        Quickshell.execDetached([
            "bash",
            Quickshell.shellPath("cache.sh"),
            Quickshell.shellDir
        ])

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs

            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
            property real corner_radius: 18
        }
    }

    FolderListModel {
        id: folderModel

        folder: "file://" + main.homeDir + "/" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        sortField: FolderListModel.Name
    }

    ListView {
        id: list

        anchors.horizontalCenter: parent.horizontalCenter
        width: main.width * 0.92
        anchors.verticalCenter: parent.verticalCenter
        height: main.height * 0.36
        focus: true
        model: folderModel
        orientation: ListView.Horizontal
        spacing: main.baseSpacing
        clip: true
        cacheBuffer: main.width
        boundsBehavior: Flickable.StopAtBounds

        property int selectedIndex: main.startPosition
        property real tileWidth: height * 0.38
        property real viewportCenterX: width / 2
        property bool ready: false

        // Extend the scrollable area on both ends so the first/last
        // wallpaper can be centered in the viewport.
        leftMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        rightMargin: leftMargin

        onCountChanged: {
            if (!ready && count > 0) {
                selectedIndex = Math.floor(count / 2)
                ensureVisibleAnimated(selectedIndex)
                ready = true
            }
        }

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1))
        }

        function activateCurrent() {
            if (count === 0) return;
            Quickshell.execDetached([
                "bash",
                Quickshell.shellPath("commands.sh"),
                folderModel.get(selectedIndex, "filePath")
            ])

            main.closeSelector()
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing
            const itemStart = i * step

            // Always center the selected tile.
            contentX = itemStart + tileWidth / 2 - viewportCenterX
        }

        function moveSelection(delta, speedMultiplier) {
            anim.v = main.speed * speedMultiplier
            selectedIndex = clampIndex(selectedIndex + delta)
            ensureVisibleAnimated(selectedIndex)
        }

        Behavior on contentX {
            enabled: list.ready && !main.scrolling

            SmoothedAnimation {
                id: anim
                property int v: main.speed
                duration: 220
                velocity: main.speed
            }
        }

        delegate: Item {
            id: delegateItem

            height: list.height
            property alias preview: content
            readonly property int pictureIndex: index
            property bool active: index === list.selectedIndex

            // Base slot width, independent of this item's own width.
            readonly property real baseWidth: list.tileWidth

            // Continuous perspective follows the actual scroll position.
            readonly property real centerOffset: (x - list.contentX + baseWidth / 2 - list.viewportCenterX) / (baseWidth + list.spacing)
            readonly property real distanceFromCenter: Math.abs(centerOffset)
            readonly property real prominence: Math.exp(-distanceFromCenter * 0.30)
            readonly property real scaleFactor: main.edgeScale + (main.zoomScale - main.edgeScale) * prominence
            readonly property real turnAngle: 0
            z: 100 - distanceFromCenter

            width: baseWidth

            Item {
                id: content

                anchors.verticalCenter: parent.verticalCenter
                x: {
                    const offset = delegateItem.centerOffset;
                    const distance = Math.abs(offset);
                    // Integrate the smooth size curve to keep gaps even.
                    const steps = 24;
                    let area = 0;
                    for (let n = 0; n < steps; n++) {
                        const t = distance * (n + 0.5) / steps;
                        area += main.edgeScale + (main.zoomScale - main.edgeScale) * Math.exp(-t * 0.30);
                    }
                    const visualDistance = delegateItem.baseWidth * area * distance / steps + list.spacing * distance;
                    return list.contentX + list.viewportCenterX + Math.sign(offset) * visualDistance - delegateItem.x - width / 2;
                }
                opacity: 0.88 + 0.12 * delegateItem.prominence
                transform: Rotation {
                    origin.x: content.width / 2
                    origin.y: content.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: delegateItem.turnAngle
                    distanceToPlane: Math.max(900, list.tileWidth * 2.5)
                }
                width: delegateItem.baseWidth * delegateItem.scaleFactor
                height: delegateItem.height *
                        Math.min(1, delegateItem.scaleFactor)

                Text {
                    id: alt

                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16

                    transform: Shear {
                        xFactor: main.skewFactor
                    }
                }

                Image {
                    id: img

                    anchors.fill: parent
                    opacity: 1.0
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true

                    source: "file://" +
                            main.homeDir + "/" +
                            configs.cache_path +
                            fileName

                    // Decode once at max zoomed size.
                    sourceSize.width:
                        delegateItem.baseWidth * main.zoomScale

                    sourceSize.height:
                        delegateItem.height

                    transform: Shear {
                        xFactor: main.skewFactor
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: img.width
                            height: img.height
                            radius: Math.min(5, configs.corner_radius)
                        }
                    }

                    Timer {
                        id: retryTimer

                        interval: 1000
                        repeat: false

                        onTriggered: {
                            const s = img.source
                            img.source = ""
                            img.source = s
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            alt.text = "Caching"
                            retryTimer.start()
                        }
                    }
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    radius: Math.min(5, configs.corner_radius)
                    border.width: 2
                    border.color: configs.border_color

                    transform: Shear {
                        xFactor: main.skewFactor
                    }
                }
            }

        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Left:
                list.moveSelection(-1, 1)
                break
            case Qt.Key_Right:
                list.moveSelection(1, 1)
                break
            case Qt.Key_Space:
            case Qt.Key_Return:
                activateCurrent()
                break
            case Qt.Key_W:
                main.closeSelector()
                break
            case Qt.Key_Escape:
                main.closeSelector()
                break
            default:
                return
            }
            event.accepted = true
        }
    }
    property bool scrolling: false
    function closeSelector() {
        main.visible = false;
        Quickshell.execDetached(["qs", "kill", "-p", Quickshell.shellPath("shell.qml")]);
    }
    Timer {
        id: scrollEnd
        interval: 140
        onTriggered: {
            main.scrolling = false;
            list.ensureVisibleAnimated(list.selectedIndex);
        }
    }
    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.LeftButton
        scrollGestureEnabled: true
        onWheel: wheel => {
            wheel.accepted = true;
            const pixels = wheel.pixelDelta;
            const precise = pixels.x !== 0 || pixels.y !== 0;
            const movement = precise ? pixels : wheel.angleDelta;
            const delta = Math.abs(movement.x) > Math.abs(movement.y) ? movement.x : movement.y;
            if (!delta || list.count === 0) return;
            main.scrolling = true;
            list.cancelFlick();
            const minimum = -list.leftMargin;
            const maximum = Math.max(minimum, list.contentWidth - list.width + list.rightMargin);
            list.contentX = Math.max(minimum, Math.min(maximum, list.contentX - delta * (precise ? 2.5 : 5)));
            list.selectedIndex = list.clampIndex(Math.round((list.contentX + list.viewportCenterX - list.tileWidth / 2) / (list.tileWidth + list.spacing)));
            scrollEnd.restart();
        }
        onClicked: mouse => {
            // Test the projected cards, including portions outside their slots.
            let hit = null;
            for (const tile of list.contentItem.children) {
                if (!tile.preview) continue;
                const p = mapToItem(tile.preview, mouse.x, mouse.y);
                if (p.x >= 0 && p.y >= 0 && p.x < tile.preview.width && p.y < tile.preview.height && (!hit || tile.z > hit.z)) hit = tile;
            }
            if (hit) {
                list.selectedIndex = hit.pictureIndex;
                list.activateCurrent();
                return;
            }
            main.closeSelector();
        }
    }

}
