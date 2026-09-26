import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import qs.Services

// VPN: status and connect/disconnect (PIA or NetworkManager VPN).
StatusMenu {
    id: menu

    title: "VPN"

    onVisibleChanged: visible ? Vpn.retain() : Vpn.release()

    header: BToggle {
        enabled: Vpn.available && !Vpn.busy
        checked: Vpn.connected
        onToggled: Vpn.toggle()
    }

    BListRow {
        width: parent.width
        icon: "shield"
        title: Vpn.busy ? I18n.tr("Changing…") : Vpn.connected ? I18n.tr("Connected") : I18n.tr("Disconnected")
        subtitle: Vpn.detail || (Vpn.provider === "pia" ? "Private Internet Access" : Vpn.provider === "nm" ? "NetworkManager" : "")
        interactive: false
        selected: Vpn.connected
    }
}
