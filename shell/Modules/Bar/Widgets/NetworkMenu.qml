import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import qs.Services

// Network: current connection, Wi-Fi switch when there is Wi-Fi hardware.
StatusMenu {
    title: I18n.tr("Network")

    BListRow {
        width: parent.width
        icon: NetworkStatus.kind === "wired" ? "ethernet" : "wifi"
        title: NetworkStatus.connected ? (NetworkStatus.kind === "wired" ? I18n.tr("Wired") : NetworkStatus.label) : I18n.tr("Disconnected")
        subtitle: NetworkStatus.kind === "wired" && NetworkStatus.wired ? NetworkStatus.wired.name : NetworkStatus.kind === "wifi" ? "Signal " + Math.round(NetworkStatus.signal * 100) + " %" : ""
        interactive: false
        selected: NetworkStatus.connected
    }

    BListRow {
        visible: NetworkStatus.hasWifi
        width: parent.width
        icon: "wifi"
        title: "Wi-Fi"
        subtitle: !NetworkStatus.wifiEnabled ? I18n.tr("Off") : NetworkStatus.kind === "wifi" ? NetworkStatus.label : I18n.tr("On, not connected")
        interactive: false

        BToggle {
            checked: NetworkStatus.wifiEnabled
            onToggled: c => NetworkStatus.setWifiEnabled(c)
        }
    }

    BText {
        visible: !NetworkStatus.hasWifi
        width: parent.width
        text: I18n.tr("No Wi-Fi adapter")
        role: "caption"
        tone: "faint"
    }
}
