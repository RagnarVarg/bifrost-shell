import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// A schema section rendered as grouped setting rows.
Flickable {
    id: page

    SettingsScroll { id: wheelScroll; flickable: page }

    property string sectionId: ""
    readonly property var section: Schema.section(sectionId)
    readonly property var keys: section ? section.settings.map(d => d.key).filter(k => Schema.isSupported(k)) : []
    readonly property var groups: {
        const out = [];
        for (const k of keys) {
            const g = Schema.def(k).group || "";
            let entry = out.find(e => e.id === g);
            if (!entry) {
                entry = { id: g, keys: [] };
                out.push(entry);
            }
            entry.keys.push(k);
        }
        return out;
    }
    readonly property int modifiedCount: Config.modifiedKeys(sectionId).length

    contentHeight: column.implicitHeight + SettingsStyle.contentPadding * 2
    clip: true
    onSectionIdChanged: contentY = 0
    boundsBehavior: Flickable.StopAtBounds

    function scrollTo(key) {
        const item = rowFor(key);
        if (item)
            contentY = Math.max(0, Math.min(contentHeight - height, item.mapToItem(column, 0, 0).y - SettingsStyle.contentPadding));
    }

    function rowFor(key) {
        for (let i = 0; i < groupRepeater.count; i++) {
            const g = groupRepeater.itemAt(i);
            const r = g ? g.rowFor(key) : null;
            if (r)
                return r;
        }
        return null;
    }

    Connections {
        target: SettingsNav

        function onHighlightKeyChanged() {
            if (SettingsNav.highlightKey)
                Qt.callLater(() => page.scrollTo(SettingsNav.highlightKey));
        }
    }

    Component.onCompleted: {
        if (SettingsNav.highlightKey)
            Qt.callLater(() => scrollTo(SettingsNav.highlightKey));
    }

    Column {
        id: column

        x: SettingsStyle.contentPadding
        y: SettingsStyle.contentPadding
        width: Math.min(page.width - SettingsStyle.contentPadding * 2, Theme.layout.pageMaxWidth)
        spacing: SettingsStyle.groupSpacing

        Item {
            width: parent.width
            height: Math.max(header.implicitHeight, resetSection.height)

            Column {
                id: header

                width: parent.width - resetSection.width - Theme.space.lg
                spacing: Theme.space.xs

                BText {
                    text: page.section ? page.section.label : ""
                    role: "title"
                }

                BText {
                    width: parent.width
                    visible: text !== ""
                    text: page.section ? page.section.description : ""
                    role: "caption"
                    tone: "muted"
                    wrapMode: Text.WordWrap
                }
            }

            BButton {
                id: resetSection

                anchors.right: parent.right
                variant: "ghost"
                size: "sm"
                icon: "reset"
                text: I18n.tr("Reset section")
                enabled: page.modifiedCount > 0
                onClicked: Config.resetSection(page.sectionId)
            }
        }

        Banner {
            visible: page.section !== null && page.section.requires !== null && page.section.requires.compositor !== undefined && !RunMode.appliesHyprlandSettings
            tone: "info"
            text: Compositor.displayName + " " + Compositor.version + " · " + I18n.tr("Bifrost runs next to another shell, so these settings are saved but applied only when Bifrost is the session shell.")
        }

        Repeater {
            id: groupRepeater

            model: page.groups

            delegate: Column {
                id: group

                required property var modelData

                function rowFor(key) { return rows.rowFor(key); }

                width: column.width
                spacing: SettingsStyle.titleSpacing

                BText {
                    visible: group.modelData.id !== ""
                    x: Theme.space.xl
                    text: Schema.groupLabel(page.sectionId, group.modelData.id)
                    role: "overline"
                    tone: "muted"
                }

                SettingsRows {
                    id: rows
                    keys: group.modelData.keys
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
