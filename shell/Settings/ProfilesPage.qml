import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text

// Presets (partial base layers) and profiles (saved snapshots of your settings).
PageBase {
    id: page

    title: I18n.tr("Profiles & presets")

    property var presets: []
    property var profiles: []
    property string status: ""
    property string confirmDelete: ""

    function refresh() {
        Ctl.run(["preset", "list", "--json"], (ok, out, data) => page.presets = data || [], page);
        Ctl.run(["profile", "list", "--json"], (ok, out, data) => page.profiles = data || [], page);
    }

    function op(args, message) {
        Ctl.run(args, (ok, out) => {
            page.status = ok ? message : out;
            page.refresh();
        }, page);
    }

    Component.onCompleted: refresh()

    BText {
        text: I18n.tr("Presets")
        role: "overline"
        tone: "muted"
    }

    BText {
        width: parent.width
        text: I18n.tr("A preset is a base layer under your own changes. Switching keeps everything you changed yourself.")
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }

    Card {
        Repeater {
            model: page.presets

            delegate: BListRow {
                required property var modelData

                width: parent.width
                icon: "layers"
                title: modelData.name
                subtitle: modelData.description
                selected: Config.preset === modelData.id
                onClicked: Config.setPreset(modelData.id)
            }
        }
    }

    BText {
        text: I18n.tr("Profiles")
        role: "overline"
        tone: "muted"
    }

    BText {
        width: parent.width
        text: I18n.tr("A profile saves all your changes and your preset. Loading a profile replaces your current changes (a backup is saved first).")
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }

    Card {
        Row {
            width: parent.width
            spacing: Theme.space.md

            BTextField {
                id: name

                width: parent.width - save.width - Theme.space.md
                icon: "plus"
                placeholder: I18n.tr("Name of new profile")
                onAccepted: t => save.clicked()
            }

            BButton {
                id: save

                text: I18n.tr("Save current")
                variant: "primary"
                enabled: name.text.trim() !== ""
                onClicked: {
                    page.op(["profile", "save", name.text.trim()], "Profilen ”" + name.text.trim() + "” sparad");
                    name.text = "";
                }
            }
        }

        BText {
            visible: page.profiles.length === 0
            text: I18n.tr("No saved profiles")
            role: "caption"
            tone: "faint"
        }

        Repeater {
            model: page.profiles

            delegate: BListRow {
                id: row

                required property var modelData

                width: parent.width
                icon: "palette"
                title: modelData.name
                subtitle: I18n.tr("%n changed settings · ", modelData.count) + (modelData.created || "").replace("T", " ")
                interactive: false

                BButton {
                    text: I18n.tr("Load")
                    size: "sm"
                    onClicked: page.op(["profile", "load", row.modelData.name], "Profilen ”" + row.modelData.name + "” laddad")
                }

                BButton {
                    text: page.confirmDelete === row.modelData.name ? I18n.tr("Confirm") : I18n.tr("Remove")
                    size: "sm"
                    variant: "ghost"
                    onClicked: {
                        if (page.confirmDelete === row.modelData.name) {
                            page.confirmDelete = "";
                            page.op(["profile", "delete", row.modelData.name], "Profilen borttagen");
                        } else {
                            page.confirmDelete = row.modelData.name;
                        }
                    }
                }
            }
        }
    }

    Banner {
        visible: page.status !== ""
        tone: "info"
        text: page.status
    }
}
