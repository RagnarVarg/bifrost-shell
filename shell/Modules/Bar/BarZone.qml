import QtQuick
import qs.Compat
import qs.Core
import qs.Components.State

// A row of widgets for one zone (left/center/right). Consecutive widgets of
// the system status group (CPU/RAM, GPU) share one area with hover details and
// a click action. `bubbles` are the glass bubbles of the boxed widget style:
// one per widget, one for a status group; BarWindow draws them.
Item {
    id: zone

    property var entries: []
    property var bar: null
    property var runs: []           // [{ x, width }] of system status groups
    property var bubbles: []        // [{ x, width }] in zone coordinates, boxed style

    readonly property bool boxed: Config.values.bar.widgetStyle === "boxed"
    // Padding inside a bubble, and the room it needs at the zone edges.
    readonly property real boxPad: boxed ? Theme.space.md : 0
    readonly property real edgePad: boxPad

    implicitWidth: row.implicitWidth + edgePad * 2
    width: implicitWidth

    function updateRuns() {
        const out = [];
        const bub = [];
        let cur = null;
        let group = null;
        for (let i = 0; i < row.children.length; i++) {
            const host = row.children[i];
            if (!host.visible || host.width <= 0 || !host.item)
                continue;
            const x = row.x + host.x;
            if (host.item.statusGroup) {
                if (cur)
                    cur.width = host.x + host.width - cur.x;
                else
                    cur = { x: host.x, width: host.width };
                if (group)
                    group.width = x + host.width + boxPad - group.x;
                else
                    bub.push(group = { x: x - boxPad, width: host.width + boxPad * 2 });
                continue;
            }
            if (cur) {
                out.push(cur);
                cur = null;
            }
            group = null;
            if (host.item.bubble !== false)
                bub.push({ x: x - boxPad, width: host.width + boxPad * 2 });
        }
        if (cur)
            out.push(cur);
        runs = out;
        bubbles = bub;
    }

    onBoxPadChanged: Qt.callLater(updateRuns)

    // The shown widget hosts, in order (IPC bar.widgets).
    function hosts(): var {
        const out = [];
        for (let i = 0; i < row.children.length; i++) {
            const h = row.children[i];
            if (h.visible && h.width > 0 && h.item)
                out.push(h);
        }
        return out;
    }

    Row {
        id: row

        x: zone.edgePad
        height: parent.height
        // Bubbles need their padding on both sides plus a visible gap.
        spacing: Metrics.barSpacing + zone.boxPad * 2
        onImplicitWidthChanged: Qt.callLater(zone.updateRuns)

        Repeater {
            model: zone.entries

            delegate: WidgetHost {
                required property var modelData

                entry: modelData
                bar: zone.bar
                width: implicitWidth
                visible: item !== null && item.shown && width > 0
                onLoaded: Qt.callLater(zone.updateRuns)
            }
        }
    }

    // Hover details and click action over each system status group, in
    // both appearances.
    Repeater {
        model: zone.runs

        delegate: Item {
            id: area

            required property var modelData
            // Anchor hover for the details menu (HoverIntent, MenuHost).
            readonly property bool hovered: mouse.containsMouse

            x: row.x + modelData.x - zone.boxPad
            width: modelData.width + zone.boxPad * 2
            height: zone.height

            StateLayer {
                anchors.fill: parent
                anchors.topMargin: Theme.space.xxs
                anchors.bottomMargin: Theme.space.xxs
                radius: Theme.control.radius
                hovered: mouse.containsMouse
                pressed: mouse.pressed
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!Config.values.bar.menus.openOnHover) {
                        details.click();
                        return;
                    }
                    details.close();
                    Platform.launch(["sh", "-c", Config.values.bar.systemStatus.clickCommand]);
                }
            }

            SystemStatusPopup {
                id: details

                bar: zone.bar
                anchorItem: area
            }
        }
    }
}
