//@ pragma UseQApplication
//@ pragma AppId bifrost.settings

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Compat
import qs.Compositor
import qs.Core
// Quickshell only registers qs.* modules reachable from the entry file's
// imports; list every module used by dynamically created components.
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text
import qs.Services
import qs.Shared
import qs.Settings
import qs.Settings.Editors

// Bifrost Settings:  bifrost-settings [section|setting-key]
// A separate process sharing Core with the shell; every change goes through
// Config into ~/.config/bifrost/config.json, which the shell applies live.
//
// Lifecycle: one resident process per session. Closing the window (Esc, ×,
// or the compositor's close) only hides it; `settings open` always makes the
// same window visible again and focuses it. `settings status` lets the
// launcher script verify that, and recover a genuinely broken instance.
ShellRoot {
    id: settings

    // True while the user wants the window; the window follows it.
    property bool shown: true

    function present(page: string) {
        SettingsNav.open(page);
        if (!shown || !window.visible) {
            shown = true;
            window.visible = true;
        }
        // A freshly mapped toplevel is focused by the compositor; one that
        // is already mapped (maybe on another workspace) must be asked for.
        focusLater.restart();
    }

    function hide() {
        SettingsNav.query = "";
        shown = false;
        window.visible = false;
    }

    Component.onCompleted: {
        void IconTheme.theme;   // starts live icon-theme switching
        SettingsNav.page = SettingsNav.firstPage();
        SettingsNav.open(Platform.env("BIFROST_SETTINGS_PAGE"));
    }

    Timer {
        id: focusLater

        interval: 120
        onTriggered: Compositor.focusProcessWindow(Platform.processId)
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            settings.present(page);
        }

        function search(query: string): void {
            settings.present("");
            SettingsNav.query = query;
        }

        function close(): void {
            settings.hide();
        }

        // Ends the process (the next open starts a fresh one).
        function quit(): void {
            Platform.quit();
        }

        // JSON for scripts: whether the window is actually mapped.
        function status(): string {
            return JSON.stringify({
                pid: Platform.processId,
                shown: settings.shown,
                visible: window.visible,
                mapped: window.backingWindowVisible,
                page: SettingsNav.page
            });
        }
    }

    FloatingWindow {
        id: window

        title: I18n.tr("Bifrost Settings")
        color: "transparent"
        visible: settings.shown
        implicitWidth: Theme.layout.settingsWidth
        implicitHeight: Theme.layout.settingsHeight
        minimumSize: Qt.size(Theme.layout.settingsMinWidth, Theme.layout.settingsMinHeight)

        // The compositor closed the toplevel (Super+Q, title bar): keep the
        // process and hide, so the next open maps the same window again.
        onClosed: settings.hide()

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: SettingsNav.query !== "" ? SettingsNav.query = "" : settings.hide()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) {
                    app.focusSearch();
                    e.accepted = true;
                }
            }

            SettingsApp {
                id: app

                anchors.fill: parent
                onCloseRequested: settings.hide()
            }
        }
    }
}
