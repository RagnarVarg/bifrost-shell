import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Export / import of .bifrost.json bundles, and a one-time import from DMS
// that is shown only when DMS's files are found.
PageBase {
    id: page

    title: "Import & export"

    property string status: ""
    property var bundles: []
    property string selected: ""
    property var preview: null
    // The DMS import is a one-time migration: shown only when DMS files exist.
    property bool dmsFound: false
    property var dms: null
    property bool dmsAppearance: false
    property bool dmsThemes: true

    function describe(v) {
        if (v === null || v === undefined)
            return "–";
        const s = typeof v === "object" ? JSON.stringify(v) : String(v);
        return s.length > 60 ? s.substring(0, 57) + "…" : s;
    }

    function scan() {
        Exec.run(["sh", "-c", "ls -1t \"$0\"/*.bifrost.json \"$1\"/*.bifrost.json 2>/dev/null", Paths.configDir + "/exports", Paths.home + "/Downloads"], (code, out) => page.bundles = out.split("\n").filter(f => f), 5000, page);
    }

    Component.onCompleted: {
        scan();
        Ctl.run(["import-dms", "--detect", "--json"], (ok, out, data) => page.dmsFound = ok && data !== null && data.found === true, page);
    }

    // ── Export
    BText {
        text: I18n.tr("Export")
        role: "overline"
        tone: "muted"
    }

    Card {
        BText {
            width: parent.width
            text: I18n.tr("Saves your changes, your preset and a custom theme (if you use one) as a .bifrost.json file.")
            role: "caption"
            tone: "muted"
            wrapMode: Text.WordWrap
        }

        BButton {
            text: I18n.tr("Export now")
            icon: "open"
            onClicked: Ctl.run(["export"], (ok, out) => {
                page.status = ok ? I18n.tr("Exported to %1").arg(out) : out;
                page.scan();
            }, page)
        }
    }

    // ── Import bundle
    BText {
        text: I18n.tr("Import")
        role: "overline"
        tone: "muted"
    }

    Card {
        BText {
            width: parent.width
            text: page.bundles.length ? I18n.tr("Files in ~/.config/bifrost/exports and ~/Downloads:") : I18n.tr("No .bifrost.json files in ~/.config/bifrost/exports or ~/Downloads.")
            role: "caption"
            tone: "muted"
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: page.bundles

            delegate: BListRow {
                required property string modelData

                width: parent.width
                icon: "layers"
                title: modelData.split("/").pop()
                subtitle: modelData.substring(0, modelData.lastIndexOf("/"))
                selected: page.selected === modelData
                onClicked: {
                    page.selected = modelData;
                    Ctl.run(["import", modelData, "--json"], (ok, out, data) => page.preview = ok ? data : { error: out }, page);
                }
            }
        }

        Column {
            visible: page.preview !== null
            width: parent.width
            spacing: Theme.space.xs

            BText {
                text: page.preview && page.preview.error ? page.preview.error : page.preview ? I18n.tr("%n change(s):", page.preview.changes.length) : ""
                role: "label"
            }

            Repeater {
                model: page.preview && page.preview.changes ? page.preview.changes : []

                delegate: BText {
                    required property var modelData

                    width: parent.width
                    text: modelData.key + ":  " + page.describe(modelData.old) + "  →  " + page.describe(modelData.new)
                    role: "mono"
                    tone: "muted"
                    elide: Text.ElideRight
                }
            }

            BButton {
                text: I18n.tr("Import")
                variant: "primary"
                enabled: page.preview !== null && !page.preview.error
                onClicked: Ctl.run(["import", page.selected, "--apply"], (ok, out) => {
                    page.status = ok ? "Importerad (backup sparad)" : out;
                    page.preview = null;
                }, page)
            }
        }
    }

    // ── DMS (only when DMS is installed)
    BText {
        visible: page.dmsFound
        text: I18n.tr("From DankMaterialShell")
        role: "overline"
        tone: "muted"
    }

    Card {
        visible: page.dmsFound
        BText {
            width: parent.width
            text: I18n.tr("Reads your DMS files (without changing them) and translates bar, dock, pinned apps, wallpaper and more into Bifrost. A one-time migration.")
            role: "caption"
            tone: "muted"
            wrapMode: Text.WordWrap
        }

        BListRow {
            width: parent.width
            title: I18n.tr("Convert DMS colour themes")
            subtitle: I18n.tr("Become selectable themes in Bifrost")
            interactive: false

            BToggle {
                checked: page.dmsThemes
                onToggled: c => page.dmsThemes = c
            }
        }

        BListRow {
            width: parent.width
            title: I18n.tr("Appearance too")
            subtitle: I18n.tr("Corner radius and spacing from DMS")
            interactive: false

            BToggle {
                checked: page.dmsAppearance
                onToggled: c => page.dmsAppearance = c
            }
        }

        BButton {
            text: I18n.tr("Preview")
            onClicked: Ctl.run(["import-dms", "--json"].concat(page.dmsAppearance ? ["--appearance"] : []), (ok, out, data) => page.dms = ok ? data : { error: out }, page)
        }

        Column {
            visible: page.dms !== null
            width: parent.width
            spacing: Theme.space.xs

            BText {
                width: parent.width
                text: page.dms && page.dms.error ? page.dms.error : page.dms ? (page.dmsThemes ? I18n.tr("%1 changes and %2 themes:").arg(page.dms.changes.length).arg(page.dms.themes.length) : I18n.tr("%n change(s):", page.dms.changes.length)) : ""
                role: "label"
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: page.dms && page.dms.changes ? page.dms.changes : []

                delegate: BText {
                    required property var modelData

                    width: parent.width
                    text: modelData.key + ":  " + page.describe(modelData.old) + "  →  " + page.describe(modelData.new)
                    role: "mono"
                    tone: "muted"
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: page.dms && page.dms.notes ? page.dms.notes.filter(n => n.key === null) : []

                delegate: BText {
                    required property var modelData

                    width: parent.width
                    text: I18n.tr("skipped: %1 (%2)").arg(modelData.value).arg(modelData.from)
                    role: "caption"
                    tone: "faint"
                    elide: Text.ElideRight
                }
            }

            BButton {
                text: I18n.tr("Import from DMS")
                variant: "primary"
                enabled: page.dms !== null && !page.dms.error
                onClicked: Ctl.run(["import-dms", "--apply"].concat(page.dmsAppearance ? ["--appearance"] : []).concat(page.dmsThemes ? ["--themes"] : []), (ok, out) => {
                    page.status = ok ? I18n.tr("Imported from DMS (backup saved)") : out;
                    page.dms = null;
                }, page)
            }
        }
    }

    Banner {
        visible: page.status !== ""
        tone: "info"
        text: page.status
    }
}
