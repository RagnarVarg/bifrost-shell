pragma Singleton

import QtQuick
import qs.Core
import Quickshell
import Quickshell.Bluetooth

// Default Bluetooth adapter and its connected devices.
Singleton {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property var connectedDevices: available && adapter.devices ? adapter.devices.values.filter(d => d.connected) : []
    // Keyboards, mice, trackpads: turning Bluetooth off would cut the user's input.
    readonly property var inputDevices: connectedDevices.filter(d => (d.icon || "").startsWith("input-") || /keyboard|mouse|trackpad|keys/i.test(d.name || ""))
    readonly property string label: !available ? I18n.tr("No adapter") : !enabled ? I18n.tr("Off") : connectedDevices.length === 0 ? I18n.tr("On") : connectedDevices.length === 1 ? (connectedDevices[0].name || connectedDevices[0].deviceName) : I18n.tr("%n devices", connectedDevices.length)

    readonly property var allDevices: available && adapter.devices ? adapter.devices.values : []
    // Known devices first (connected, then paired), then ones discovered nearby.
    readonly property var pairedDevices: allDevices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || nameOf(a).localeCompare(nameOf(b)))
    // Nameless devices (the "name" is just the MAC address) are noise.
    readonly property var nearbyDevices: allDevices.filter(d => !d.paired && !d.bonded && hasRealName(d)).sort((a, b) => nameOf(a).localeCompare(nameOf(b)))

    function hasRealName(d): bool {
        const n = d.name || d.deviceName || "";
        return n !== "" && !/^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(n);
    }
    readonly property bool discovering: available && adapter.discovering

    function nameOf(d): string {
        return d ? (d.name || d.deviceName || d.address) : "";
    }

    function isInput(d): bool {
        return !!d && ((d.icon || "").startsWith("input-") || /keyboard|mouse|trackpad|keys/i.test(d.name || ""));
    }

    function iconOf(d): string {
        const i = d ? d.icon || "" : "";
        return i.indexOf("audio") >= 0 || i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 ? "volume" : i.startsWith("input-") ? "apps" : i.indexOf("phone") >= 0 ? "display" : "bluetooth";
    }

    function setEnabled(on: bool) {
        if (available)
            adapter.enabled = on;
    }

    function setDiscovering(on: bool) {
        if (available && adapter.enabled)
            adapter.discovering = on;
    }

    function connect(d) {
        if (d)
            d.connect();
    }

    function disconnect(d) {
        if (d)
            d.disconnect();
    }

    // Pair, trust (so it reconnects) and connect a nearby device.
    function pair(d) {
        if (!d)
            return;
        d.trusted = true;
        d.pair();
    }

    function forget(d) {
        if (d)
            d.forget();
    }
}
