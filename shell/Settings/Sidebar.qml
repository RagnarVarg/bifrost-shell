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

    // A page was chosen (also the one already open): compact Settings shows it.
    signal navigated

    // Search first, as in a system settings window; the brand sits in the
    // footer.
    BTextField {
        id: search

        x: Theme.space.md
        y: Theme.space.xl
        width: parent.width - Theme.space.md * 2
        icon: "search"
        placeholder: I18n.tr("Search settings")
        text: SettingsNav.query
        onTextChanged: SettingsNav.query = text
        Keys.onEscapePressed: text = ""
    }

    Flickable {
        id: list

        anchors.top: search.bottom
        anchors.topMargin: Theme.space.sm
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
                        bottomPadding: Theme.space.xs
                        text: category.modelData.label
                        role: "caption"
                        font.weight: Theme.font.weight.semibold
                        tone: category.modelData.advanced ? "warning" : "faint"
                    }

                    Repeater {
                        model: category.sections

                        delegate: NavItem {
                            required property var modelData

                            icon: modelData.icon
                            label: modelData.label
                            pageId: modelData.id
                            badge: Config.modifiedKeys(modelData.id).length
                            current: SettingsNav.query === "" && SettingsNav.page === modelData.id
                            onClicked: {
                                SettingsNav.open(modelData.id);
                                sidebar.navigated();
                            }
                        }
                    }

                    Repeater {
                        model: category.pages

                        delegate: NavItem {
                            required property var modelData

                            icon: modelData.icon
                            label: modelData.label
                            pageId: modelData.id
                            current: SettingsNav.query === "" && SettingsNav.page === modelData.id
                            onClicked: {
                                SettingsNav.open(modelData.id);
                                sidebar.navigated();
                            }
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

    Row {
        id: footer

        x: Theme.space.lg
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.lg
        width: parent.width - Theme.space.lg * 2
        spacing: Theme.space.md

        BIcon {
            source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
            size: Theme.icon.size.lg
            color: Theme.palette.silverBright
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - Theme.icon.size.lg - parent.spacing
            anchors.verticalCenter: parent.verticalCenter

            BText {
                text: "Bifrost " + I18n.tr("Settings")
                role: "label"
                width: parent.width
                elide: Text.ElideRight
            }

            BText {
                width: parent.width
                text: Compositor.displayName + " " + Compositor.version + " · " + RunMode.mode
                role: "caption"
                tone: "faint"
                elide: Text.ElideRight
            }
        }
    }

    function focusSearch() {
        search.forceActiveFocus();
    }
}
