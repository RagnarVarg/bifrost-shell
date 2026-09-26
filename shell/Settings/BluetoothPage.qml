import QtQuick
import qs.Core
import qs.Shared

// Bluetooth devices: adapter, scan, pair, connect, forget.
PageBase {
    title: "Bluetooth"

    Card {
        BluetoothDevices {
            width: parent.width
        }
    }
}
