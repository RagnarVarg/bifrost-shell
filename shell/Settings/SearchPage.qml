import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Search results across all supported settings.
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

        x: SettingsStyle.contentPadding
        y: SettingsStyle.contentPadding
        width: Math.min(page.width - SettingsStyle.contentPadding * 2, SettingsStyle.pageMaxWidth)
        spacing: Theme.space.md

        BText {
            text: I18n.tr("%n result(s) for “%1”", page.results.length).arg(SettingsNav.query)
            role: "title"
            font.pixelSize: Theme.typography.title.size * SettingsStyle.titleScale
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: page.results

            delegate: BListRow {
                id: result

                required property var modelData

                width: column.width
                title: modelData.label
                subtitle: Schema.section(modelData.section).label + " · " + page.describe(Config.get(modelData.key))
                icon: Schema.section(modelData.section).icon
                onClicked: SettingsNav.open(modelData.key)

                BIconButton {
                    icon: "chevron-right"
                    size: "sm"
                    onClicked: SettingsNav.open(result.modelData.key)
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
