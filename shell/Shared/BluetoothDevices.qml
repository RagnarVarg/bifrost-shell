import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Services

// Bluetooth device list used by the control center and Settings:
// adapter switch, scan, known devices (connect/disconnect/forget) and nearby
// devices (pair). Disconnecting or forgetting a keyboard/mouse needs a second
// click, since it would cut the user's input.
Column {
    id: list

    property bool compact: false       // control center: fewer controls
    property string armed: ""          // "<action>:<address>" awaiting a second click

    spacing: Theme.space.sm

    function arm(action, d) {
        armed = action + ":" + d.address;
        disarm.restart();
    }

    function isArmed(action, d) {
        return armed === action + ":" + d.address;
    }

    function guarded(action, d, fn) {
        if (BluetoothStatus.isInput(d) && !isArmed(action, d)) {
            arm(action, d);
            return;
        }
        armed = "";
        fn(d);
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: list.armed = ""
    }

    // Scan while the list is shown; stop again when it goes away.
    Component.onCompleted: if (BluetoothStatus.enabled)
        BluetoothStatus.setDiscovering(true)
    Component.onDestruction: BluetoothStatus.setDiscovering(false)

    BListRow {
        visible: !list.compact
        width: parent.width
        icon: "bluetooth"
        title: "Bluetooth"
        subtitle: BluetoothStatus.available ? (BluetoothStatus.adapter.name || "Adapter") : I18n.tr("No adapter found")
        interactive: false

        BToggle {
            enabled: BluetoothStatus.available
            checked: BluetoothStatus.enabled
            onToggled: c => BluetoothStatus.setEnabled(c)
        }
    }

    BText {
        visible: BluetoothStatus.available && !BluetoothStatus.enabled
        text: I18n.tr("Bluetooth is off")
        role: "caption"
        tone: "muted"
    }

    component DeviceRow: Item {
        id: row

        property var device: null
        readonly property bool connected: device && device.connected
        readonly property bool busy: device && (device.pairing || device.state === 3 || device.state === 2)

        width: list.width
        height: Theme.control.height.lg + Theme.space.xs

        StateLayer {
            anchors.fill: parent
            radius: Theme.radius.md
            hovered: hover.hovered
            selected: row.connected
        }

        HoverHandler {
            id: hover
        }

        BIcon {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            name: BluetoothStatus.iconOf(row.device)
            size: Theme.icon.size.sm
            color: row.connected ? Theme.color.text : Theme.color.iconMuted
        }

        Column {
            anchors.left: glyph.right
            anchors.leftMargin: Theme.space.md
            anchors.right: actions.left
            anchors.rightMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter

            BText {
                width: parent.width
                text: BluetoothStatus.nameOf(row.device)
                role: "label"
                elide: Text.ElideRight
            }

            BText {
                width: parent.width
                text: list.isArmed("disconnect", row.device) ? I18n.tr("Click again to disconnect") : list.isArmed("forget", row.device) ? I18n.tr("Click again to forget") : row.busy ? I18n.tr("Connecting…") : row.connected ? (I18n.tr("Connected") + (row.device.batteryAvailable ? " · " + Math.round(row.device.battery * 100) + " %" : "")) : row.device && (row.device.paired || row.device.bonded) ? I18n.tr("Not connected") : I18n.tr("Available")
                role: "caption"
                tone: list.isArmed("disconnect", row.device) || list.isArmed("forget", row.device) ? "warning" : row.connected ? "primary" : "muted"
                elide: Text.ElideRight
            }
        }

        Row {
            id: actions

            anchors.right: parent.right
            anchors.rightMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.xs

            BButton {
                visible: row.device && (row.device.paired || row.device.bonded)
                size: "sm"
                variant: row.connected ? "ghost" : "secondary"
                text: row.connected ? I18n.tr("Disconnect") : I18n.tr("Connect")
                enabled: !row.busy
                onClicked: row.connected ? list.guarded("disconnect", row.device, d => BluetoothStatus.disconnect(d)) : BluetoothStatus.connect(row.device)
            }

            BButton {
                visible: row.device && !row.device.paired && !row.device.bonded
                size: "sm"
                variant: "primary"
                text: I18n.tr("Pair")
                enabled: !row.busy
                onClicked: BluetoothStatus.pair(row.device)
            }

            BIconButton {
                visible: !list.compact && row.device && (row.device.paired || row.device.bonded)
                icon: "trash"
                size: "sm"
                onClicked: list.guarded("forget", row.device, d => BluetoothStatus.forget(d))
            }
        }
    }

    BText {
        visible: BluetoothStatus.enabled && BluetoothStatus.pairedDevices.length > 0
        text: I18n.tr("My devices")
        role: "overline"
        tone: "muted"
    }

    Repeater {
        model: BluetoothStatus.enabled ? BluetoothStatus.pairedDevices : []

        delegate: DeviceRow {
            required property var modelData

            device: modelData
        }
    }

    Item {
        visible: BluetoothStatus.enabled
        width: parent.width
        height: Theme.control.height.sm

        BText {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Nearby")
            role: "overline"
            tone: "muted"
        }

        BText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothStatus.discovering ? I18n.tr("Searching…") : ""
            role: "caption"
            tone: "faint"
        }
    }

    BText {
        visible: BluetoothStatus.enabled && BluetoothStatus.nearbyDevices.length === 0
        text: BluetoothStatus.discovering ? I18n.tr("No new devices found yet") : I18n.tr("Search is off")
        role: "caption"
        tone: "faint"
    }

    Repeater {
        model: BluetoothStatus.enabled ? BluetoothStatus.nearbyDevices.slice(0, list.compact ? 6 : 40) : []

        delegate: DeviceRow {
            required property var modelData

            device: modelData
        }
    }
}
