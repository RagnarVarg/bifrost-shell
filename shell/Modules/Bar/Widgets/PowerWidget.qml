import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Modules

// Power button: opens the system menu (about, settings, sleep, restart,
// shut down, lock, log out …). The full-screen power menu stays available
// through IPC (`power toggle`).
BarWidget {
    id: widget

    implicitWidth: button.implicitWidth

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        selected: menu.isOpen
        onClicked: menu.click()

        BIcon {
            name: "power"
            size: Theme.icon.size.md
            color: Theme.color.text
        }
    }

    SystemMenu {
        id: menu

        bar: widget.bar
        anchorItem: button
    }

    Connections {
        target: ShellState

        // "system" toggles the menu; "system:about|recent|forceQuit" opens
        // it on that page (e.g. a Force Quit keybind).
        function onStatusMenuRequested(screen, name) {
            if (!name.startsWith("system") || !widget.bar || screen !== widget.bar.modelData.name)
                return;
            const page = name.split(":")[1] || "";
            if (!page) {
                menu.toggle();
                return;
            }
            menu.open();
            menu.openPage(page);
        }
    }
}
