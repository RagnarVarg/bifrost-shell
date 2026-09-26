pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Core
import qs.Compat

// Power profile via power-profiles-daemon (powerprofilesctl).
// profile: "power-saver" | "balanced" | "performance".
Singleton {
    id: root

    // UPower's aggregate display device follows battery signals (no polling).
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property real charge: hasBattery ? Math.max(0, Math.min(1, battery.percentage)) : 0
    readonly property bool acConnected: hasBattery && !UPower.onBattery
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool discharging: hasBattery && battery.state === UPowerDeviceState.Discharging
    readonly property bool full: hasBattery && battery.state === UPowerDeviceState.FullyCharged
    readonly property bool critical: hasBattery && !acConnected && charge <= 0.05
    readonly property bool low: hasBattery && !acConnected && charge <= 0.20
    readonly property real remainingSeconds: !hasBattery ? 0 : charging ? battery.timeToFull : discharging ? battery.timeToEmpty : 0
    readonly property string batteryStatus: !hasBattery ? I18n.tr("No battery detected") : full ? I18n.tr("Fully charged") : charging ? I18n.tr("Charging") : critical ? I18n.tr("Critical battery") : low ? I18n.tr("Low battery") : discharging ? I18n.tr("Discharging") : I18n.tr("AC connected")

    property bool available: false
    property string profile: ""
    property var profiles: []
    readonly property var order: ["power-saver", "balanced", "performance"]

    function set(p: string) {
        profile = p;
        Exec.run(["powerprofilesctl", "set", p], () => root.refresh());
    }

    function refresh() {
        Exec.run(["powerprofilesctl", "get"], (code, out) => {
            available = code === 0;
            if (available)
                profile = out.trim();
        });
    }

    Component.onCompleted: {
        refresh();
        Exec.run(["powerprofilesctl", "list"], (code, out) => {
            if (code === 0)
                profiles = (out.match(/^\*?\s*([a-z-]+):/gm) || []).map(l => l.replace(/[*:\s]/g, "")).sort((a, b) => root.order.indexOf(a) - root.order.indexOf(b));
        });
    }
}
