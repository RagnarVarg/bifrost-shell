import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Search results across all supported settings: one card of rows (section
// tile, label, section · current value). A row opens the section scrolled to
// the setting and highlights it.
Flickable {
    id: page

    SettingsScroll { id: wheelScroll; flickable: page }

    readonly property var results: Schema.search(SettingsNav.query).filter(r => Schema.isSupported(r.key) && Schema.inMode(r.key))

    contentHeight: column.implicitHeight + SettingsStyle.contentPadding * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function describe(v) {
        if (v === null || v === undefined)
            return I18n.tr("theme");
        if (typeof v === "boolean")
            return v ? I18n.tr("on") : I18n.tr("off");
        if (typeof v === "object")
            return Array.isArray(v) ? v.join(", ") : "…";
        return String(v);
    }

    Column {
        id: column

        x: SettingsStyle.pageX(page.width, width)
        y: SettingsStyle.contentPadding
        width: Math.min(page.width - SettingsStyle.contentPadding * 2, SettingsStyle.pageMaxWidth)
        spacing: SettingsStyle.groupSpacing

        BText {
            text: I18n.tr("%n result(s) for “%1”", page.results.length).arg(SettingsNav.query)
            role: "title"
            font.pixelSize: Theme.typography.title.size * SettingsStyle.titleScale
            width: parent.width
            wrapMode: Text.WordWrap
        }

        SettingsNavList {
            visible: page.results.length > 0

            Repeater {
                model: page.results

                delegate: SettingsNavRow {
                    required property var modelData
                    required property int index
                    readonly property var section: Schema.section(modelData.section)

                    divider: index > 0
                    icon: section ? section.icon : ""
                    tileId: modelData.section
                    title: modelData.label
                    subtitle: (section ? section.label : "") + " · " + page.describe(Config.get(modelData.key))
                    onClicked: SettingsNav.open(modelData.key)
                }
            }
        }
    }

    BScrollIndicator {
        interactive: true
        onDragStarted: wheelScroll.motion.stop()
        flickable: page
    }
}
