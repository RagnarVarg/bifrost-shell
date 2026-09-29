import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Text

// The Settings UI: sidebar + current page, with global banners. Adapts to
// its width (SettingsStyle): in a compact window it is one column, either the
// navigation or the page (with a back button and the search field on top).
Item {
    id: app

    property bool embedded: false
    // Compact only: the page is shown instead of the navigation.
    property bool showPage: true

    signal closeRequested

    function focusSearch() {
        if (SettingsStyle.compact && showPage)
            pageSearch.input.forceActiveFocus();
        else
            sidebar.focusSearch();
    }

    Binding {
        target: SettingsStyle
        property: "windowWidth"
        value: app.width
    }

    // Typing in the navigation's search field shows the results page; the
    // page's own field takes over with the same text.
    Connections {
        target: SettingsNav

        function onQueryChanged() {
            if (SettingsNav.query !== "" && SettingsStyle.compact && !app.showPage) {
                app.showPage = true;
                pageSearch.input.forceActiveFocus();
                pageSearch.input.cursorPosition = SettingsNav.query.length;
            }
        }
    }

    GlassSurface {
        id: glass

        anchors.fill: parent
        material: Theme.materials.settings
        paintEnabled: !app.embedded

        Sidebar {
            id: sidebar

            width: SettingsStyle.sidebarWidth
            height: parent.height
            visible: !SettingsStyle.compact || !app.showPage
            onNavigated: app.showPage = true
        }

        Rectangle {
            visible: !SettingsStyle.compact
            x: sidebar.width
            width: Theme.border.hairline
            height: parent.height
            color: Theme.color.divider
        }

        Item {
            id: main

            visible: !SettingsStyle.compact || app.showPage
            x: SettingsStyle.compact ? 0 : sidebar.width + Theme.border.hairline
            width: parent.width - x
            height: parent.height

            // Compact: back to the navigation, and search (results replace
            // the page) next to it.
            Row {
                id: compactBar

                visible: SettingsStyle.compact
                x: Theme.space.lg
                y: Theme.space.lg
                width: main.width - x - close.width - Theme.space.lg * 2
                spacing: Theme.space.md

                BIconButton {
                    id: back

                    icon: "chevron-left"
                    onClicked: {
                        SettingsNav.query = "";
                        app.showPage = false;
                    }
                }

                BTextField {
                    id: pageSearch

                    width: parent.width - back.width - parent.spacing
                    icon: "search"
                    placeholder: I18n.tr("Search settings")
                    text: SettingsNav.query
                    onTextChanged: SettingsNav.query = text
                    Keys.onEscapePressed: text = ""
                }
            }

            Column {
                id: banners

                x: SettingsStyle.contentPadding
                y: SettingsStyle.compact ? compactBar.y + compactBar.height + Theme.space.sm : Theme.space.lg
                width: Math.min(main.width - SettingsStyle.contentPadding * 2 - (SettingsStyle.compact ? 0 : close.width), SettingsStyle.pageMaxWidth)
                spacing: Theme.space.sm

                Banner {
                    visible: Config.loadError !== ""
                    tone: "danger"
                    text: I18n.tr("config.json can't be read (%1). Changes are not saved until the file is fixed.").arg(Config.loadError)
                }

                Banner {
                    id: reloadBanner

                    property bool busy: false

                    visible: ApplyState.needsReload && ApplyState.shellRunning
                    tone: "warning"
                    text: I18n.tr("%n change(s) take effect when the shell reloads.", ApplyState.pendingReload.length)
                    actionText: busy ? I18n.tr("Reloading…") : I18n.tr("Reload shell")
                    onAction: {
                        busy = true;
                        InstanceIpc.call(Paths.shellDir, "bifrost", "reload", [], ok => {
                            reloadBanner.busy = false;
                            if (!ok)
                                console.warn("[bifrost] settings: shell reload failed");
                        });
                    }
                }

                Banner {
                    id: restartBanner

                    property string result: ""

                    visible: ApplyState.needsRestart && ApplyState.shellRunning
                    tone: "warning"
                    text: restartBanner.result === "unsupported" ? I18n.tr("%n change(s) take effect when the shell restarts. This shell isn't run by bifrost.service, so restart it yourself.", ApplyState.pendingRestart.length) : I18n.tr("%n change(s) take effect when the shell restarts.", ApplyState.pendingRestart.length)
                    actionText: restartBanner.result === "busy" ? I18n.tr("Restarting…") : restartBanner.result === "unsupported" ? "" : I18n.tr("Restart shell")
                    onAction: {
                        restartBanner.result = "busy";
                        InstanceIpc.call(Paths.shellDir, "bifrost", "restart", [], (ok, out) => restartBanner.result = ok && out.indexOf("unsupported") >= 0 ? "unsupported" : "");
                    }
                }
            }

            Loader {
                id: pageLoader

                readonly property var info: SettingsNav.pageInfo(SettingsNav.page)

                anchors.top: banners.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                sourceComponent: SettingsNav.query !== "" ? searchPage : info && info.kind === "section" ? sectionPage : info && info.page === "InputPage" ? inputPage : info && info.page === "KeybindsPage" ? keybindsPage : info && info.page === "ThemeBrowserPage" ? themeBrowserPage : info && info.page === "NetworkPage" ? networkPage : info && info.page === "ProfilesPage" ? profilesPage : info && info.page === "TransferPage" ? transferPage : info && info.page === "BluetoothPage" ? bluetoothPage : info && info.page === "DisplayPage" ? displayPage : dataPage
            }

            BIconButton {
                id: close

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.lg
                icon: "close"
                onClicked: app.closeRequested()
            }
        }
    }

    Component {
        id: sectionPage

        SectionPage {
            sectionId: SettingsNav.page
        }
    }

    Component {
        id: searchPage

        SearchPage {}
    }

    Component {
        id: dataPage

        DataPage {}
    }


    Component { id: inputPage; InputPage {} }

    Component { id: keybindsPage; KeybindsPage {} }

    Component {
        id: themeBrowserPage
        ThemeBrowserPage {}
    }

    Component {
        id: networkPage
        NetworkPage {}
    }

    Component {
        id: profilesPage

        ProfilesPage {}
    }

    Component {
        id: transferPage

        TransferPage {}
    }

    Component {
        id: bluetoothPage

        BluetoothPage {}
    }

    Component {
        id: displayPage

        DisplayPage {}
    }
}
