import QtQuick
import qs.Core
import qs.Components.Icons

// Opens Bifrost Settings.
BarWidget {
    implicitWidth: button.implicitWidth

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        onClicked: Launch.openSettings("")

        BIcon {
            name: "settings"
            size: Theme.icon.size.md
            color: Theme.color.text
        }
    }
}
