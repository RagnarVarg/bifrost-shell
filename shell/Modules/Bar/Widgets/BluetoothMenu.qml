import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Services
import qs.Shared

// Bluetooth: switch, devices (connect/pair), link to Settings.
StatusMenu {
    id: menu

    title: "Bluetooth"

    header: BToggle {
        enabled: BluetoothStatus.available
        checked: BluetoothStatus.enabled
        onToggled: c => BluetoothStatus.setEnabled(c)
    }

    // Created only while open, so scanning runs only then.
    Loader {
        width: parent.width
        active: menu.visible

        sourceComponent: BluetoothDevices {
            compact: true
        }
    }

    BButton {
        size: "sm"
        variant: "ghost"
        icon: "settings"
        text: I18n.tr("Bluetooth settings")
        onClicked: {
            menu.close();
            Launch.openSettings("bluetooth");
        }
    }
}
