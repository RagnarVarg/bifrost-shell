import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import "KeyNames.js" as KeyNames

// Settings → Keybindings → Shortcuts: every shortcut Bifrost binds, your own,
// and (read-only) the other ones in your Hyprland config; search, change,
// turn off, reset, add. Data and every change go through
// `bifrostctl keybinds` (the generator's own catalogue); the shell applies the
// saved config through CompositorSync like any other Hyprland setting.
PageBase {
    id: page

    title: I18n.tr("Shortcuts")

    property var entries: []
    property var groups: ({})
    property var actions: []
    property bool live: false
    property bool loaded: false
    property string expanded: ""
    property string query: ""

    readonly property var groupOrder: ["shell", "media", "screenshots", "windows", "workspaces", "custom", "external"]

    function refresh() {
        Ctl.run(["keybinds", "list", "--json"], (ok, out, data) => {
            page.loaded = true;
            if (!data)
                return;
            page.entries = data.entries;
            page.groups = data.groups;
            page.actions = data.actions;
            page.live = data.live;
        }, page);
    }

    function groupLabel(g): string {
        return g === "custom" ? I18n.tr("Your own") : g === "external" ? I18n.tr("Other shortcuts in your Hyprland config") : I18n.tr(groups[g] || g);
    }

    function matches(e): bool {
        const q = query.trim().toLowerCase();
        if (q === "")
            return true;
        const title = I18n.tr(e.label || e.description || "").replace("%1", e.arg || "");
        const keys = KeyNames.parts(e.keys).map(p => KeyNames.label(p, t => I18n.tr(t))).join(" ");
        return [title, e.action || "", e.keys || "", keys].some(s => s.toLowerCase().indexOf(q) >= 0);
    }

    // Dev aid for screenshots: BIFROST_DEV_KEYBINDS="<search>|<id to expand>".
    Component.onCompleted: {
        refresh();
        const dev = (Platform.env("BIFROST_DEV_KEYBINDS") || "").split("|");
        if (dev[0])
            search.text = dev[0];
        if (dev[1])
            expanded = dev[1];
    }

    BText {
        width: parent.width
        text: I18n.tr("Click a shortcut to change it. Changes are saved at once and Bifrost applies them to Hyprland through its generated bifrost.lua.")
        tone: "muted"
        wrapMode: Text.WordWrap
    }

    BTextField {
        id: search

        width: parent.width
        icon: "search"
        placeholder: I18n.tr("Search shortcuts")
        onTextChanged: page.query = text
    }

    BText {
        visible: page.loaded && page.entries.length === 0
        width: parent.width
        text: I18n.tr("Shortcuts could not be read.")
        tone: "danger"
    }

    Repeater {
        model: page.groupOrder

        delegate: Column {
            id: group

            required property string modelData
            readonly property var items: page.entries.filter(e => e.group === modelData && page.matches(e))

            visible: items.length > 0 || (modelData === "custom" && page.query === "")
            width: parent.width
            spacing: SettingsStyle.titleSpacing

            BText {
                text: page.groupLabel(group.modelData)
                role: "overline"
                tone: "muted"
            }

            Card {
                Repeater {
                    model: group.items

                    delegate: KeybindRow {
                        required property var modelData

                        entry: modelData
                        entries: page.entries
                        expanded: page.expanded === modelData.id
                        onToggled: page.expanded = expanded ? "" : modelData.id
                        onChanged: {
                            page.expanded = "";
                            page.refresh();
                        }
                    }
                }

                KeybindRow {
                    visible: group.modelData === "custom" && page.expanded === "new"
                    entry: ({ id: "new", keys: "", source: "custom" })
                    entries: page.entries
                    actions: page.actions
                    expanded: page.expanded === "new"
                    onToggled: page.expanded = ""
                    onChanged: {
                        page.expanded = "";
                        page.refresh();
                    }
                }

                BButton {
                    visible: group.modelData === "custom" && page.expanded !== "new"
                    icon: "plus"
                    text: I18n.tr("Add shortcut")
                    onClicked: page.expanded = "new"
                }
            }
        }
    }

    BText {
        visible: page.loaded && !page.live
        width: parent.width
        text: I18n.tr("Hyprland's current shortcuts could not be read, so shortcuts from your own Hyprland config are not shown or checked.")
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }
}
