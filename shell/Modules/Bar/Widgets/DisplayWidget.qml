import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Modules

// Display button: opens the display menu (HDR on/off).
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
            name: "display"
            size: Theme.icon.size.sm
            color: Theme.color.text
        }
    }

    DisplayMenu {
        id: menu

        bar: widget.bar
        anchorItem: button
    }

    Connections {
        target: ShellState

        function onStatusMenuRequested(screen, name) {
            if (name === "display" && widget.bar && screen === widget.bar.modelData.name)
                menu.toggle();
        }
    }
}
