import QtQuick
import qs.Core
import qs.Services
import qs.Shared
import qs.Components.Controls
import qs.Components.Text

PageBase {
    id: page
    title: I18n.tr("Network")
    property string editing: ""
    property string confirmDelete: ""
    property var draft: ({})
    readonly property var profileFields: [
        ["connection.autoconnect", I18n.tr("Autoconnect"), ["yes", "no"]],
        ["connection.autoconnect-priority", I18n.tr("Autoconnect priority")],
        ["connection.metered", I18n.tr("Metered connection"), ["unknown", "yes", "no"]],
        ["ipv4.method", "IPv4", ["auto", "manual", "disabled"]],
        ["ipv4.addresses", I18n.tr("IPv4 addresses (CIDR)")],
        ["ipv4.gateway", I18n.tr("IPv4 gateway")],
        ["ipv4.dns", I18n.tr("IPv4 DNS")],
        ["ipv4.dns-search", I18n.tr("IPv4 search domains")],
        ["ipv4.routes", I18n.tr("IPv4 routes")],
        ["ipv6.method", "IPv6", ["auto", "manual", "disabled"]],
        ["ipv6.addresses", I18n.tr("IPv6 addresses (CIDR)")],
        ["ipv6.gateway", I18n.tr("IPv6 gateway")],
        ["ipv6.dns", I18n.tr("IPv6 DNS")],
        ["ipv6.dns-search", I18n.tr("IPv6 search domains")],
        ["ipv6.routes", I18n.tr("IPv6 routes")],
        ["proxy.method", I18n.tr("Proxy method"), ["none", "auto"]],
        ["proxy.pac-url", I18n.tr("Proxy PAC URL")]
    ]
    function update(key, value) { draft = Object.assign({}, draft, { [key]: value }); }
    Component.onCompleted: NetworkStatus.refreshManagement()

    BText {
        width: parent.width
        visible: NetworkStatus.managementError !== ""
        text: NetworkStatus.managementError
        wrapMode: Text.Wrap
        role: "caption"
        tone: "warning"
    }
    Card {
        WifiNetworks { width: parent.width }
        Flow {
            width: parent.width
            spacing: Theme.space.sm
            BButton {
                text: I18n.tr("Rescan")
                enabled: NetworkStatus.hasWifi && NetworkStatus.wifiEnabled && !NetworkStatus.managementBusy
                onClicked: NetworkStatus.rescan()
            }
            BButton {
                text: I18n.tr("Hidden or enterprise network…")
                visible: NetworkStatus.connectionEditorAvailable
                onClicked: NetworkStatus.openConnectionEditor("wifi")
            }
        }
    }
    Card {
        visible: NetworkStatus.hasWifi && NetworkStatus.hiddenNetworkAvailable
        BText { text: I18n.tr("Hidden Wi-Fi network"); role: "heading" }
        BTextField { id: hiddenSsid; width: parent.width; placeholder: I18n.tr("Network name (SSID)") }
        BTextField { id: hiddenPassword; width: parent.width; password: true; placeholder: I18n.tr("WPA personal password (empty for open network)") }
        BDropdown {
            id: hiddenInterface
            width: parent.width
            model: NetworkStatus.interfaces.filter(d => d.type === "wifi").map(d => ({ value: d.name, label: d.name }))
            currentValue: model.length ? model[0].value : ""
            onActivated: value => currentValue = value
        }
        BButton {
            text: I18n.tr("Connect")
            enabled: !NetworkStatus.managementBusy && NetworkStatus.wifiEnabled && hiddenSsid.text !== "" && hiddenInterface.currentValue !== ""
            onClicked: {
                NetworkStatus.connectHidden(hiddenSsid.text, hiddenPassword.text, hiddenInterface.currentValue);
                hiddenPassword.text = "";
            }
        }
    }
    BText { text: I18n.tr("Interfaces"); role: "heading" }
    Repeater {
        model: NetworkStatus.interfaces.filter(d => d.type !== "loopback")
        delegate: Card {
            id: device
            required property var modelData
            BText {
                width: parent.width
                text: device.modelData.name + " · " + device.modelData.type + " · " + device.modelData.state
                wrapMode: Text.Wrap
                role: "label"
            }
            Flow {
                width: parent.width
                spacing: Theme.space.sm
                BButton {
                    text: I18n.tr("Details")
                    onClicked: NetworkStatus.readDetails(device.modelData.name)
                }
                BButton {
                    text: I18n.tr("Connect")
                    enabled: !NetworkStatus.managementBusy
                    onClicked: NetworkStatus.setDeviceEnabled(device.modelData.name, true)
                }
                BButton {
                    text: I18n.tr("Disconnect")
                    enabled: !NetworkStatus.managementBusy
                    onClicked: NetworkStatus.setDeviceEnabled(device.modelData.name, false)
                }
            }
            BText {
                width: parent.width
                visible: NetworkStatus.detailInterface === device.modelData.name
                text: Object.entries(NetworkStatus.details).filter(e => /GENERAL\.(DEVICE|HWADDR|STATE|CONNECTION)|IP[46]\.(ADDRESS|GATEWAY|DNS|ROUTE)|CARRIER/.test(e[0])).map(e => e[0] + ": " + e[1]).join("\n")
                wrapMode: Text.Wrap
                role: "caption"
            }
        }
    }
    BText { text: I18n.tr("Saved connections and VPN"); role: "heading" }
    Repeater {
        model: NetworkStatus.profiles.filter(p => p.type !== "loopback")
        delegate: Card {
            id: profile
            required property var modelData
            BText {
                width: parent.width
                text: profile.modelData.name + " · " + profile.modelData.type + (profile.modelData.active ? " · " + I18n.tr("Connected") : "")
                wrapMode: Text.Wrap
                role: "label"
            }
            Flow {
                width: parent.width
                spacing: Theme.space.sm
                BButton {
                    text: profile.modelData.active ? I18n.tr("Disconnect") : I18n.tr("Connect")
                    enabled: !NetworkStatus.managementBusy
                    onClicked: profile.modelData.active ? NetworkStatus.deactivateProfile(profile.modelData.uuid) : NetworkStatus.activateProfile(profile.modelData.uuid)
                }
                BButton {
                    text: I18n.tr("Edit")
                    onClicked: {
                        page.editing = profile.modelData.uuid;
                        page.draft = {};
                        NetworkStatus.readProfile(page.editing);
                    }
                }
                BButton {
                    text: page.confirmDelete === profile.modelData.uuid ? I18n.tr("Confirm forget") : I18n.tr("Forget")
                    enabled: !NetworkStatus.managementBusy
                    onClicked: {
                        if (page.confirmDelete === profile.modelData.uuid) {
                            NetworkStatus.deleteProfile(profile.modelData.uuid);
                            page.confirmDelete = "";
                        } else page.confirmDelete = profile.modelData.uuid;
                    }
                }
            }
            Column {
                visible: page.editing === profile.modelData.uuid
                width: parent.width
                spacing: Theme.space.md
                Repeater {
                    model: parent.visible ? page.profileFields : []
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: Theme.space.xs
                        BText { width: parent.width; text: parent.modelData[1]; role: "caption"; wrapMode: Text.Wrap }
                        BDropdown {
                            visible: parent.modelData.length > 2
                            width: parent.width
                            property string field: parent.modelData[0]
                            model: parent.modelData[2] || []
                            currentValue: page.draft[field] !== undefined ? page.draft[field] : NetworkStatus.profileDetails[field] || ""
                            onActivated: value => page.update(field, value)
                        }
                        BTextField {
                            visible: parent.modelData.length < 3
                            width: parent.width
                            property string field: parent.modelData[0]
                            text: NetworkStatus.profileDetails[field] === "--" ? "" : NetworkStatus.profileDetails[field] || ""
                            onTextChanged: if (activeFocus || input.activeFocus) page.update(field, text)
                        }
                    }
                }
                BText {
                    width: parent.width
                    text: I18n.tr("Saved changes take effect when this connection is reconnected.")
                    wrapMode: Text.Wrap
                    role: "caption"
                }
                Flow {
                    width: parent.width
                    spacing: Theme.space.sm
                    BButton {
                        text: I18n.tr("Save")
                        enabled: !NetworkStatus.managementBusy && Object.keys(page.draft).length > 0
                        onClicked: NetworkStatus.saveProfile(profile.modelData.uuid, page.draft)
                    }
                    BButton { text: I18n.tr("Close"); onClicked: page.editing = "" }
                }
            }
        }
    }
}
