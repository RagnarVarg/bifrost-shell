import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls

// Which outputs something appears on: "all" or specific monitor names.
EditorBase {
    id: editor

    readonly property var items: Array.isArray(value) ? value : []
    readonly property bool all: items.indexOf("all") >= 0
    readonly property var names: Compositor.monitors.map(m => m.name).concat(items.filter(n => n !== "all" && !Compositor.monitors.some(m => m.name === n)))

    implicitWidth: row.implicitWidth

    function toggle(name) {
        let next = items.filter(n => n !== "all");
        next = next.indexOf(name) >= 0 ? next.filter(n => n !== name) : next.concat([name]);
        set(next.length ? next : ["all"]);
    }

    Row {
        id: row

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.xs

        BChip {
            text: I18n.tr("All displays")
            selected: editor.all
            onClicked: editor.set(["all"])
        }

        Repeater {
            model: editor.names

            delegate: BChip {
                required property string modelData

                text: modelData
                selected: !editor.all && editor.items.indexOf(modelData) >= 0
                onClicked: editor.toggle(modelData)
            }
        }
    }
}
