import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text

// Navigation built from schema/index.json: categories → supported sections
// (+ custom pages), with a count of modified settings per section.
Item {
    id: sidebar

    Column {
        id: top

        x: Theme.space.lg
        y: Theme.space.xl
        width: parent.width - Theme.space.lg * 2
        spacing: Theme.space.lg

        Row {
            spacing: Theme.space.md

            BIcon {
                source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
                size: Theme.icon.size.xl
                color: Theme.palette.silverBright
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                BText {
                    text: "Bifrost"
                    role: "heading"
                }

                BText {
                    text: I18n.tr("Settings")
                    role: "caption"
                    tone: "muted"
                }
            }
        }

        BTextField {
            id: search

            width: parent.width
            icon: "search"
            placeholder: I18n.tr("Search settings")
            text: SettingsNav.query
            onTextChanged: SettingsNav.query = text
            Keys.onEscapePressed: text = ""
        }
    }

    Flickable {
        id: list

        anchors.top: top.bottom
        anchors.topMargin: Theme.space.lg
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.space.md
        x: Theme.space.md
        width: parent.width - Theme.space.md * 2
        contentHeight: nav.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: nav

            width: list.width
            spacing: Theme.space.xxs

            Repeater {
                model: Schema.categories

                delegate: Column {
                    id: category

                    required property var modelData
                    readonly property var sections: Schema.sectionsInCategory(modelData.id).filter(s => Schema.isSectionSupported(s.id))
                    readonly property var pages: modelData.pages || []

                    width: nav.width
                    spacing: Theme.space.xxs
                    visible: sections.length + pages.length > 0

                    Item {
                        width: parent.width
                        height: Theme.space.lg
                    }

                    BText {
                        x: Theme.space.md
                        text: category.modelData.label
                        role: "overline"
                        tone: category.modelData.advanced ? "warning" : "faint"
                    }

                    Repeater {
                        model: category.sections

                        delegate: NavItem {
                            required property var modelData

                            icon: modelData.icon
                            label: modelData.label
                            badge: Config.modifiedKeys(modelData.id).length
                            current: SettingsNav.query === "" && SettingsNav.page === modelData.id
                            onClicked: SettingsNav.open(modelData.id)
                        }
                    }

                    Repeater {
                        model: category.pages

                        delegate: NavItem {
                            required property var modelData

                            icon: modelData.icon
                            label: modelData.label
                            current: SettingsNav.query === "" && SettingsNav.page === modelData.id
                            onClicked: SettingsNav.open(modelData.id)
                        }
                    }
                }
            }
        }

        BScrollIndicator {
        interactive: true
            flickable: list
        }
    }

    BText {
        id: footer

        x: Theme.space.xl
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.lg
        width: parent.width - Theme.space.xl * 2
        text: Compositor.displayName + " " + Compositor.version + " · " + RunMode.mode
        role: "mono"
        tone: "faint"
        elide: Text.ElideRight
    }

    function focusSearch() {
        search.forceActiveFocus();
    }
}
