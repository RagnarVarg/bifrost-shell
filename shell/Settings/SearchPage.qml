import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
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

        Item {
            visible: page.results.length > 0
            width: parent.width
            height: rows.implicitHeight + SettingsStyle.groupInset * 2

            SettingsGroupSurface {
                anchors.fill: parent
            }

            Column {
                id: rows

                y: SettingsStyle.groupInset
                width: parent.width

                Repeater {
                    model: page.results

                    delegate: Item {
                        id: result

                        required property var modelData
                        required property int index
                        readonly property var section: Schema.section(modelData.section)

                        width: rows.width
                        height: Math.max(tile.height, texts.implicitHeight) + SettingsStyle.rowPaddingY * 2

                        SettingsDivider {
                            visible: result.index > 0
                            x: texts.x
                            width: parent.width - x
                        }

                        StateLayer {
                            anchors.fill: parent
                            anchors.margins: SettingsStyle.groupInset
                            radius: Theme.radius.md
                            hovered: mouse.containsMouse
                            pressed: mouse.pressed
                        }

                        Rectangle {
                            id: tile

                            x: SettingsStyle.rowPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.control.tile.size
                            height: width
                            radius: Theme.control.tile.radius
                            color: SettingsStyle.tileColor(result.modelData.section)
                            border.width: Theme.border.hairline
                            border.color: Theme.color.innerBorder

                            BIcon {
                                anchors.centerIn: parent
                                name: result.section ? result.section.icon : ""
                                size: Theme.control.tile.icon
                                color: Theme.color.tileIcon
                            }
                        }

                        Column {
                            id: texts

                            anchors.left: tile.right
                            anchors.leftMargin: Theme.space.lg
                            anchors.right: chevron.left
                            anchors.rightMargin: Theme.space.md
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: SettingsStyle.descriptionSpacing

                            BText {
                                width: parent.width
                                text: result.modelData.label
                                role: "label"
                                elide: Text.ElideRight
                            }

                            BText {
                                width: parent.width
                                text: (result.section ? result.section.label : "") + " · " + page.describe(Config.get(result.modelData.key))
                                role: "caption"
                                tone: "muted"
                                elide: Text.ElideRight
                            }
                        }

                        BIcon {
                            id: chevron

                            anchors.right: parent.right
                            anchors.rightMargin: SettingsStyle.rowPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron-right"
                            size: Theme.icon.size.sm
                            color: Theme.color.iconMuted
                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsNav.open(result.modelData.key)
                        }
                    }
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
