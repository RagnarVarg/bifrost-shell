import QtQuick
import qs.Compat
import qs.Services
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Bar widget layout: left / center / right zones. Widgets come from
// schema/widgets.json; each entry keeps its own extra properties.
EditorBase {
    id: editor

    readonly property var zones: [{ id: "left", label: I18n.tr("Left") }, { id: "center", label: I18n.tr("Centre") }, { id: "right", label: I18n.tr("Right") }]
    readonly property var layout: value && typeof value === "object" ? value : ({ left: [], center: [], right: [] })
    property var registry: []

    wide: true
    implicitWidth: Theme.layout.pageMaxWidth
    implicitHeight: row.implicitHeight

    function info(id) {
        return registry.find(w => w.id === id) || { id: id, label: id, icon: "apps" };
    }

    function used(id) {
        return zones.some(z => (layout[z.id] || []).some(w => w.id === id));
    }

    function update(fn) {
        const next = JSON.parse(JSON.stringify(layout));
        for (const z of zones)
            next[z.id] = next[z.id] || [];
        fn(next);
        set(next);
    }

    function move(zone, index, delta) {
        update(l => {
            const list = l[zone];
            const j = index + delta;
            if (j < 0 || j >= list.length)
                return;
            const [item] = list.splice(index, 1);
            list.splice(j, 0, item);
        });
    }

    function moveZone(zone, index, delta) {
        const zi = zones.findIndex(z => z.id === zone) + delta;
        if (zi < 0 || zi >= zones.length)
            return;
        update(l => {
            const [item] = l[zone].splice(index, 1);
            l[zones[zi].id].push(item);
        });
    }

    function remove(zone, index) {
        update(l => l[zone].splice(index, 1));
    }

    function add(zone, id) {
        update(l => l[zone].push({ id: id }));
    }

    Row {
        id: row

        width: parent.width
        spacing: Theme.space.md

        Repeater {
            model: editor.zones

            delegate: Rectangle {
                id: zoneCard

                required property var modelData
                readonly property var entries: editor.layout[modelData.id] || []

                width: (row.width - row.spacing * 2) / 3
                height: zoneColumn.implicitHeight + Theme.space.md * 2
                radius: Theme.radius.md
                color: Theme.color.fieldFill
                border.width: Theme.border.hairline
                border.color: Theme.color.hairline

                Column {
                    id: zoneColumn

                    x: Theme.space.md
                    y: Theme.space.md
                    width: parent.width - Theme.space.md * 2
                    spacing: Theme.space.xs

                    BText {
                        text: zoneCard.modelData.label
                        role: "overline"
                        tone: "muted"
                    }

                    Repeater {
                        model: zoneCard.entries

                        delegate: Item {
                            id: entry

                            required property int index
                            required property var modelData
                            readonly property var meta: editor.info(modelData.id)

                            width: zoneColumn.width
                            height: Theme.control.height.md

                            StateLayer {
                                anchors.fill: parent
                                radius: Theme.control.radius
                                hovered: entryMouse.containsMouse
                            }

                            MouseArea {
                                id: entryMouse

                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            BIcon {
                                id: entryIcon

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.space.sm
                                anchors.verticalCenter: parent.verticalCenter
                                name: entry.meta.icon
                                size: Theme.icon.size.sm
                            }

                            BText {
                                anchors.left: entryIcon.right
                                anchors.leftMargin: Theme.space.sm
                                anchors.right: tools.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr(entry.meta.label)
                                role: "caption"
                                elide: Text.ElideRight
                            }

                            Row {
                                id: tools

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entryMouse.containsMouse || toolsHover.hovered

                                HoverHandler {
                                    id: toolsHover
                                }

                                BIconButton {
                                    icon: "arrow-up"
                                    size: "sm"
                                    enabled: entry.index > 0
                                    onClicked: editor.move(zoneCard.modelData.id, entry.index, -1)
                                }

                                BIconButton {
                                    icon: "arrow-down"
                                    size: "sm"
                                    enabled: entry.index < zoneCard.entries.length - 1
                                    onClicked: editor.move(zoneCard.modelData.id, entry.index, 1)
                                }

                                BIconButton {
                                    icon: "chevron-left"
                                    size: "sm"
                                    visible: zoneCard.modelData.id !== "left"
                                    onClicked: editor.moveZone(zoneCard.modelData.id, entry.index, -1)
                                }

                                BIconButton {
                                    icon: "chevron-right"
                                    size: "sm"
                                    visible: zoneCard.modelData.id !== "right"
                                    onClicked: editor.moveZone(zoneCard.modelData.id, entry.index, 1)
                                }

                                BIconButton {
                                    icon: "close"
                                    size: "sm"
                                    onClicked: editor.remove(zoneCard.modelData.id, entry.index)
                                }
                            }
                        }
                    }

                    BDropdown {
                        width: parent.width
                        placeholder: I18n.tr("Add widget")
                        model: editor.registry.filter(w => !w.since && (w.multiple || !editor.used(w.id))).map(w => ({ value: w.id, label: w.id === "battery" && !Power.hasBattery ? I18n.tr("No battery detected") : I18n.tr(w.label), enabled: w.id !== "battery" || Power.hasBattery }))
                        onActivated: v => editor.add(zoneCard.modelData.id, v)
                    }
                }
            }
        }
    }

    JsonReader {
        id: reader
    }

    Component.onCompleted: {
        const res = reader.read(Paths.schemaDir + "/widgets.json");
        registry = res.ok ? res.data.widgets : [];
    }
}
