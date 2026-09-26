import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import "KeyNames.js" as KeyNames

// One shortcut on the Shortcuts page: what it does, its keys and state, and
// (expanded) an editor. Every change goes through `bifrostctl keybinds`, the
// one keybind backend; a combination in use is checked first and saving it
// needs a second, explicit "Save anyway".
//   entry: an item of `bifrostctl keybinds list --json` .entries, or
//          { id: "new" } to add one (with `actions` to choose from).
Item {
    id: row

    property var entry: ({})
    property var entries: []          // all entries, to name conflicts
    property var actions: []          // for a new one: [{ label, action }]
    property bool expanded: false
    readonly property bool settingRow: true
    readonly property bool isNew: entry.id === "new"
    readonly property bool editable: isNew || entry.source === "default" || entry.source === "custom"

    property string newKeys: ""
    property var conflicts: []
    property string error: ""
    property bool busy: false
    property string action: ""
    property string command: ""

    signal toggled
    signal changed

    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight + Theme.space.md * 2

    function title(e): string {
        if (e.id === "new")
            return I18n.tr("New shortcut");
        return I18n.tr(e.label || e.description || "").replace("%1", e.arg || "");
    }

    function nameOf(id): string {
        const e = entries.find(x => x.id === id);
        return e ? title(e) + (e.source === "external" ? " (" + I18n.tr("your Hyprland config") + ")" : "") : id;
    }

    readonly property string stateText: {
        switch (entry.state) {
        case "changed":
            return I18n.tr("Changed");
        case "off":
            return I18n.tr("Off");
        case "groupOff":
            return I18n.tr("Off with its group");
        case "replaced":
            return I18n.tr("Replaced by your own shortcut");
        case "disabled":
            return I18n.tr("Key disabled");
        case "external":
            return I18n.tr("From your Hyprland config · read-only");
        case "custom":
            return entry.label === entry.action ? "" : entry.action;
        default:
            return "";
        }
    }

    function reset() {
        newKeys = entry.keys || "";
        conflicts = [];
        error = "";
        action = actions.length ? actions[0].action : "";
        command = "";
        capture.keys = newKeys;
    }

    onExpandedChanged: if (expanded)
        reset()
    onActionsChanged: if (isNew && action === "" && actions.length)
        action = actions[0].action

    function actionArg(): string {
        return action === "run" ? "run " + command.trim() : action;
    }

    function check(keys) {
        error = "";
        conflicts = [];
        Ctl.run(["keybinds", "check", entry.id, keys, "--json"], (ok, out, data) => {
            if (!data || !data.ok) {
                row.error = I18n.tr("Not a key combination");
                return;
            }
            row.newKeys = data.keys;
            capture.keys = data.keys;
            row.conflicts = data.conflicts.map(c => c.id);
        }, row);
    }

    function run(args) {
        busy = true;
        Ctl.run(args.concat(["--json"]), (ok, out, data) => {
            row.busy = false;
            if (ok) {
                row.changed();
                return;
            }
            if (data && data.error === "conflict")
                row.conflicts = data.conflicts.map(c => c.id);
            else
                row.error = data && data.error ? data.error : out;
        }, row);
    }

    function save() {
        const force = conflicts.length > 0 ? ["--force"] : [];
        if (isNew)
            run(["keybinds", "add", newKeys, actionArg()].concat(force));
        else
            run(["keybinds", "set", entry.id, newKeys].concat(force));
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.md
        color: row.expanded ? Theme.color.controlFill : "transparent"
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.radius.md
        hovered: head.containsMouse && !row.expanded
    }

    MouseArea {
        id: head

        width: parent.width
        height: top.height + Theme.space.md * 2
        hoverEnabled: true
        enabled: row.editable
        cursorShape: row.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.toggled()
    }

    Column {
        id: column

        x: Theme.space.md
        y: Theme.space.md
        width: parent.width - Theme.space.md * 2
        spacing: Theme.space.md

        Item {
            id: top

            width: parent.width
            height: Math.max(texts.implicitHeight, chips.implicitHeight)

            Column {
                id: texts

                anchors.left: parent.left
                anchors.right: chips.left
                anchors.rightMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xxs

                BText {
                    width: parent.width
                    text: row.title(row.entry)
                    tone: row.entry.active === false ? "muted" : "primary"
                    elide: Text.ElideRight
                }

                BText {
                    visible: text !== ""
                    width: parent.width
                    text: row.stateText
                    role: "caption"
                    tone: "muted"
                    elide: Text.ElideRight
                }

                Row {
                    visible: (row.entry.conflicts || []).length > 0
                    spacing: Theme.space.xs

                    BIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "warning"
                        size: Theme.icon.size.sm
                        color: Theme.color.warning
                    }

                    BText {
                        text: I18n.tr("Also on these keys: %1").arg((row.entry.conflicts || []).map(id => row.nameOf(id)).join(", "))
                        role: "caption"
                        tone: "warning"
                    }
                }
            }

            KeyChips {
                id: chips

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                keys: row.entry.keys || ""
                faint: row.entry.active === false
            }
        }

        Column {
            visible: row.expanded
            width: parent.width
            spacing: Theme.space.md

            BDropdown {
                visible: row.isNew
                width: parent.width
                model: row.actions.map(a => ({ value: a.action, label: I18n.tr(a.label) })).concat([{ value: "run", label: I18n.tr("Run a command…") }])
                currentValue: row.action
                onActivated: v => row.action = v
            }

            BTextField {
                visible: row.isNew && row.action === "run"
                width: parent.width
                placeholder: "bifrost-terminal btop"
                text: row.command
                onTextChanged: row.command = text
            }

            KeyCaptureField {
                id: capture

                width: parent.width
                keys: row.newKeys
                onRecorded: k => row.check(k)
            }

            BText {
                visible: row.entry.source === "default" && row.entry.state === "changed"
                width: parent.width
                text: I18n.tr("Default: %1").arg(row.entry.defaultKeys || "")
                role: "caption"
                tone: "muted"
            }

            Banner {
                visible: row.conflicts.length > 0
                width: parent.width
                tone: "warning"
                text: I18n.tr("Already used by %1. Saving anyway turns Bifrost's other shortcut off; one from your Hyprland config is replaced while Bifrost runs.").arg(row.conflicts.map(id => row.nameOf(id)).join(", "))
            }

            BText {
                visible: row.error !== ""
                width: parent.width
                text: row.error
                role: "caption"
                tone: "danger"
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: Theme.space.sm

                BButton {
                    variant: "primary"
                    text: row.conflicts.length > 0 ? I18n.tr("Save anyway") : I18n.tr("Save")
                    enabled: !row.busy && row.newKeys !== "" && (row.isNew ? row.actionArg().trim() !== "run" : KeyNames.id(row.newKeys) !== KeyNames.id(row.entry.keys || ""))
                    onClicked: row.save()
                }

                BButton {
                    visible: !row.isNew && row.entry.state !== "off"
                    text: row.entry.source === "custom" ? I18n.tr("Remove") : I18n.tr("Turn off")
                    enabled: !row.busy
                    onClicked: row.run(["keybinds", "off", row.entry.id])
                }

                BButton {
                    visible: row.entry.source === "default" && row.entry.state !== "default" && row.entry.state !== "groupOff"
                    text: I18n.tr("Reset to default")
                    enabled: !row.busy
                    onClicked: row.run(["keybinds", "reset", row.entry.id])
                }

                BButton {
                    variant: "ghost"
                    text: I18n.tr("Cancel")
                    onClicked: {
                        capture.stop();
                        row.toggled();
                    }
                }
            }
        }
    }
}
