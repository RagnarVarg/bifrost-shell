import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Text

PageBase {
    id: page
    title: I18n.tr("Get more themes")
    property var themes: []
    property bool busy: false
    property bool offline: false
    property string error: ""
    property string query: ""
    property int limit: 30
    readonly property var matches: themes.filter(t => (t.name + " " + t.author + " " + t.variant).toLowerCase().includes(query.toLowerCase()))

    function load(refresh) {
        busy = true;
        Ctl.run(["themes", "browse", "--json"].concat(refresh ? ["--refresh"] : []), (ok, out, data) => {
            busy = false;
            error = ok ? "" : I18n.tr("Could not load themes");
            if (ok && data) { themes = data.themes; offline = data.offline; }
        }, page);
    }
    function action(kind, theme) {
        busy = true;
        Ctl.run(["themes", kind, theme.id, "--json"], (ok, out, data) => {
            busy = false;
            error = ok ? "" : I18n.tr("Could not change theme");
            if (ok) load(false);
        }, page);
    }
    Component.onCompleted: load(false)

    BText {
        width: parent.width
        text: I18n.tr("Tinted Theming palettes, adapted to Bifrost. Materials, typography and icons are kept.")
        wrapMode: Text.Wrap
        role: "caption"
    }
    BTextField {
        width: parent.width
        placeholder: I18n.tr("Search themes")
        onTextChanged: { page.query = text; page.limit = 30; }
    }
    BButton {
        text: page.busy ? I18n.tr("Loading…") : I18n.tr("Refresh")
        enabled: !page.busy
        onClicked: page.load(true)
    }
    BText {
        width: parent.width
        visible: page.offline || page.error !== ""
        text: page.error || I18n.tr("Offline: showing cached themes. Installed themes still work.")
        wrapMode: Text.Wrap
        role: "caption"
        tone: "warning"
    }
    Repeater {
        model: page.matches.slice(0, page.limit)
        delegate: Card {
            id: card
            required property var modelData
            readonly property bool active: Config.get("appearance.theme") === modelData.id
            BText {
                width: parent.width
                text: card.modelData.name + " · " + (card.modelData.variant === "dark" ? I18n.tr("Dark") : I18n.tr("Light"))
                role: "heading"
                wrapMode: Text.Wrap
            }
            BText {
                width: parent.width
                text: card.modelData.author
                role: "caption"
                wrapMode: Text.Wrap
            }
            // Palette preview uses the exact downloaded color data.
            Row {
                width: parent.width
                Repeater {
                    model: ["00", "01", "02", "05", "08", "0A", "0B", "0C", "0D", "0E"]
                    delegate: Rectangle {
                        required property string modelData
                        width: parent.width / 10
                        height: Theme.control.height.lg
                        color: card.modelData.palette[modelData]
                    }
                }
            }
            BText {
                width: parent.width
                text: I18n.tr("Compatible with Bifrost") + " · " + card.modelData.version.slice(0, 12)
                role: "caption"
                wrapMode: Text.Wrap
            }
            Flow {
                width: parent.width
                spacing: Theme.space.sm
                BButton {
                    visible: !card.modelData.installed || card.modelData.updateAvailable
                    text: card.modelData.installed ? I18n.tr("Update") : I18n.tr("Install")
                    enabled: !page.busy
                    onClicked: page.action("install", card.modelData)
                }
                BButton {
                    visible: card.modelData.installed
                    text: card.active ? I18n.tr("Applied") : I18n.tr("Apply")
                    enabled: !page.busy && !card.active
                    onClicked: {
                        Config.set("appearance.mode", card.modelData.variant);
                        Config.set("appearance.theme", card.modelData.id);
                    }
                }
                BButton {
                    text: I18n.tr("Details")
                    onClicked: Platform.launch(["xdg-open", card.modelData.source])
                }
                BButton {
                    visible: card.modelData.installed
                    text: I18n.tr("Remove")
                    enabled: !page.busy && !card.active
                    onClicked: page.action("remove", card.modelData)
                }
            }
        }
    }
    BButton {
        visible: page.matches.length > page.limit
        text: I18n.tr("Show more")
        onClicked: page.limit += 30
    }
}
