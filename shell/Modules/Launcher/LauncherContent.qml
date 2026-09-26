import QtQuick
import qs.Shared
import qs.Core
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text
import qs.Modules
import qs.Modules.Launcher.Providers

// The launcher: search on top, results grid below, wherever it opens
// (launcher.placement, see Launcher): on its own in the centre, grown out of
// the dock, or out of the bar's launcher button. Keyboard: type to search,
// arrows move, Enter opens, Esc clears, then closes.
Item {
    id: content

    readonly property int columns: Config.values.launcher.columns
    // Set by the host so the panel fits on the screen.
    property bool active: visible
    onActiveChanged: if (active && ShellState.launcherOpen) Qt.callLater(prepare)
    property real maxHeight: Theme.layout.launcherHeight
    readonly property var providers: [apps]
    property string query: ""
    readonly property var results: {
        const all = [];
        for (const p of providers)
            all.push.apply(all, p.search(query));
        return all.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
    }

    implicitWidth: Theme.layout.launcherWidth
    implicitHeight: Math.min(Theme.layout.launcherHeight, maxHeight)

    function close() {
        contextMenu.close();
        ShellState.launcherOpen = false;
    }

    function run(item) {
        if (!item)
            return;
        close();
        item.run();
    }

    // Fresh on every open: the query IPC asked for (launcher search), first
    // result selected, typing goes to the search field.
    function prepare() {
        if (!active || !ShellState.launcherOpen) return;
        search.text = ShellState.launcherQuery;
        content.query = search.text;
        grid.currentIndex = 0;
        search.input.forceActiveFocus();
    }

    Component.onCompleted: if (ShellState.launcherOpen)
        prepare()

    Connections {
        target: ShellState

        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen)
                Qt.callLater(content.prepare);
            else
                contextMenu.close();
        }
    }

    AppContextMenu { id: contextMenu }

    AppsProvider {
        id: apps
    }

    BTextField {
        id: search

        x: Theme.space.xl
        y: Theme.space.xl
        width: parent.width - Theme.space.xl * 2
        size: "lg"
        icon: "search"
        placeholder: I18n.tr("Search apps")
        onTextChanged: {
            content.query = text;
            grid.currentIndex = 0;
        }
        onAccepted: content.run(content.results[grid.currentIndex])

        onKeyPressed: e => {
            const cols = content.columns;
            const n = content.results.length;
            let i = grid.currentIndex;
            if (e.key === Qt.Key_Escape && contextMenu.opened) {
                contextMenu.close();
                e.accepted = true;
                return;
            }
            if (e.key === Qt.Key_Escape) {
                if (search.text !== "")
                    search.text = "";
                else
                    content.close();
            } else if (e.key === Qt.Key_Right) {
                if (search.input.cursorPosition < search.text.length && search.text !== "")
                    return;
                i = Math.min(n - 1, i + 1);
            } else if (e.key === Qt.Key_Left) {
                if (search.input.cursorPosition > 0 && search.text !== "")
                    return;
                i = Math.max(0, i - 1);
            } else if (e.key === Qt.Key_Down) {
                i = Math.min(n - 1, i + cols);
            } else if (e.key === Qt.Key_Up) {
                i = Math.max(0, i - cols);
            } else if (e.key === Qt.Key_PageDown) {
                i = Math.min(n - 1, i + cols * 3);
            } else if (e.key === Qt.Key_PageUp) {
                i = Math.max(0, i - cols * 3);
            } else {
                return;
            }
            grid.currentIndex = i;
            e.accepted = true;
        }
    }

    GridView {
        id: grid

        anchors.top: search.bottom
        anchors.topMargin: Theme.space.lg
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.space.sm
        x: Theme.space.lg
        width: parent.width - Theme.space.lg * 2
        cellWidth: width / content.columns
        cellHeight: Metrics.launcherIconSize + Theme.typography.caption.size * 2 + Theme.space.xl * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: content.results
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: false
        currentIndex: 0
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

        delegate: Item {
            id: tile

            required property int index
            required property var modelData
            readonly property bool current: GridView.isCurrentItem

            width: grid.cellWidth
            height: grid.cellHeight

            StateLayer {
                anchors.fill: parent
                anchors.margins: Theme.space.xs
                radius: Theme.radius.lg
                hovered: mouse.containsMouse
                pressed: mouse.pressed
                selected: tile.current
            }

            Image {
                id: appIcon

                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.space.xl
                width: Metrics.launcherIconSize
                height: width
                source: tile.modelData.icon
                sourceSize: Qt.size(width * 2, height * 2)
                smooth: true
                asynchronous: true
            }

            BText {
                anchors.top: appIcon.bottom
                anchors.topMargin: Theme.space.sm
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Theme.space.md * 2
                horizontalAlignment: Text.AlignHCenter
                text: tile.modelData.title
                role: "caption"
                tone: tile.current ? "primary" : "muted"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton && tile.modelData.app) {
                        contextMenu.item = { key: tile.modelData.app.id, app: tile.modelData.app, windows: [] };
                        contextMenu.open(tile);
                    } else if (event.button === Qt.LeftButton) {
                        content.run(tile.modelData);
                    }
                }
            }
        }

        BScrollIndicator {
            flickable: grid
        }
    }

    BText {
        anchors.centerIn: grid
        visible: content.results.length === 0
        text: I18n.tr("No results for “%1”").arg(content.query)
        role: "body"
        tone: "muted"
    }

    BText {
        id: footer

        x: Theme.space.xl
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.lg
        width: parent.width - Theme.space.xl * 2
        text: I18n.tr("%n apps  ·  ↵ open  ·  ←↑↓→ choose  ·  Esc close", content.results.length)
        role: "mono"
        tone: "faint"
    }
}
