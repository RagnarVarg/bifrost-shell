import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// One group of the Shortcuts page (e.g. "windows") on another page: the same
// rows (KeybindRow: record, change, turn off, reset, conflict check) and the
// same backend (`bifrostctl keybinds`), so both pages always agree.
//   KeybindGroupCard { group: "windows" }
Column {
    id: card

    required property string group
    property var entries: []
    property var groups: ({})
    property bool loaded: false
    property string expanded: ""
    readonly property var items: entries.filter(e => e.group === group)

    width: parent ? parent.width : 0
    spacing: SettingsStyle.titleSpacing

    function refresh() {
        Ctl.run(["keybinds", "list", "--json"], (ok, out, data) => {
            card.loaded = true;
            if (!data)
                return;
            card.entries = data.entries;
            card.groups = data.groups;
        }, card);
    }

    Component.onCompleted: refresh()

    BText {
        text: I18n.tr(card.groups[card.group] || card.group)
        role: "heading"
    }

    Card {
        BText {
            visible: card.loaded && card.items.length === 0
            width: parent.width
            text: I18n.tr("Shortcuts could not be read.")
            tone: "danger"
        }

        Repeater {
            model: card.items

            delegate: KeybindRow {
                required property var modelData

                entry: modelData
                entries: card.entries
                expanded: card.expanded === modelData.id
                onToggled: card.expanded = expanded ? "" : modelData.id
                onChanged: {
                    card.expanded = "";
                    card.refresh();
                }
            }
        }

        BButton {
            variant: "ghost"
            icon: "keyboard"
            text: I18n.tr("All shortcuts")
            onClicked: SettingsNav.open("keybinds/shortcuts")
        }
    }
}
