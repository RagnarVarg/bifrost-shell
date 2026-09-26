import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Services

// Wi-Fi: the switch and the networks in view (NetworkStatus:
// NetworkManager). A click connects; a new protected network first asks for
// its password, in the row. The connected network is marked and can be
// disconnected; saved ones can be forgotten. Scans while shown. Used by the
// control center.
Column {
    id: list

    property string asking: ""                // network whose password is asked for

    spacing: Theme.space.xxs

    Component.onCompleted: NetworkStatus.retainScan()
    Component.onDestruction: NetworkStatus.releaseScan()

    BListRow {
        width: parent.width
        icon: NetworkStatus.wifiEnabled ? "wifi" : "wifi-off"
        title: "Wi-Fi"
        subtitle: !NetworkStatus.hasWifi ? I18n.tr("No Wi-Fi adapter") : !NetworkStatus.wifiHardwareEnabled ? I18n.tr("Turned off by the hardware switch") : !NetworkStatus.wifiEnabled ? I18n.tr("Off") : NetworkStatus.wifiNetwork ? NetworkStatus.wifiNetwork.name : I18n.tr("On, not connected")
        interactive: false

        BToggle {
            enabled: NetworkStatus.hasWifi && NetworkStatus.wifiHardwareEnabled
            checked: NetworkStatus.wifiEnabled
            onToggled: c => NetworkStatus.setWifiEnabled(c)
        }
    }

    BText {
        visible: NetworkStatus.hasWifi && NetworkStatus.wifiEnabled && NetworkStatus.networks.length === 0
        width: parent.width
        leftPadding: Theme.space.md
        text: I18n.tr("Searching for networks…")
        role: "caption"
        tone: "faint"
    }

    Repeater {
        model: NetworkStatus.hasWifi && NetworkStatus.wifiEnabled ? NetworkStatus.networks : []

        delegate: Column {
            id: entry

            required property var modelData
            readonly property string name: modelData.name
            readonly property string security: NetworkStatus.securityOf(modelData)
            readonly property bool connected: modelData.connected
            readonly property bool connecting: !connected && (modelData.stateChanging || NetworkStatus.pending === name)
            readonly property string failure: NetworkStatus.failures[name] || ""
            readonly property bool asking: list.asking === name

            width: list.width
            spacing: Theme.space.xxs

            function activate() {
                if (connected || connecting)
                    return;
                if (security === "enterprise")
                    return;
                if (NetworkStatus.needsPassword(modelData) || failure !== "" && security === "psk") {
                    list.asking = asking ? "" : name;
                    if (list.asking)
                        Qt.callLater(() => password.input.forceActiveFocus());
                    return;
                }
                NetworkStatus.connectTo(modelData);
            }

            Item {
                width: parent.width
                height: Theme.control.height.lg

                StateLayer {
                    anchors.fill: parent
                    radius: Theme.radius.md
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                    selected: entry.connected
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: entry.connected || entry.security === "enterprise" ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: entry.activate()
                }

                BIcon {
                    id: glyph

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    name: NetworkStatus.signalIcon(entry.modelData.signalStrength)
                    size: Theme.icon.size.sm
                    color: entry.connected ? Theme.color.text : Theme.color.iconMuted
                }

                Column {
                    anchors.left: glyph.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        width: parent.width
                        spacing: Theme.space.xs

                        BText {
                            width: Math.min(implicitWidth, parent.width - (lock.visible ? lock.width + parent.spacing : 0))
                            text: entry.name
                            role: "label"
                            tone: entry.connected ? "primary" : "muted"
                            elide: Text.ElideRight
                        }

                        BIcon {
                            id: lock

                            visible: entry.security !== "open"
                            anchors.verticalCenter: parent.verticalCenter
                            name: "lock"
                            size: Theme.icon.size.sm
                            color: Theme.color.iconMuted
                        }
                    }

                    BText {
                        width: parent.width
                        text: entry.connecting ? I18n.tr("Connecting…") : entry.connected ? (NetworkStatus.internet === "full" || NetworkStatus.internet === "unknown" ? I18n.tr("Connected") : NetworkStatus.internet === "portal" ? I18n.tr("Connected · sign-in needed") : I18n.tr("Connected · no internet")) : entry.failure !== "" ? entry.failure : entry.security === "enterprise" ? I18n.tr("Enterprise network: not supported here yet") : entry.modelData.known ? I18n.tr("Saved") : entry.security === "open" ? I18n.tr("Open") : I18n.tr("Secured")
                        role: "caption"
                        tone: entry.failure !== "" && !entry.connecting ? "danger" : entry.connected ? "accent" : "faint"
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: actions

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xxs

                    BButton {
                        visible: entry.connected || entry.connecting
                        size: "sm"
                        variant: "ghost"
                        text: I18n.tr("Disconnect")
                        onClicked: NetworkStatus.disconnectFrom(entry.modelData)
                    }

                    BIconButton {
                        visible: entry.modelData.known && !entry.connecting
                        size: "sm"
                        icon: "trash"
                        onClicked: NetworkStatus.forget(entry.modelData)
                    }
                }
            }

            // The password, asked for in place.
            Row {
                visible: entry.asking
                x: Theme.space.md
                width: parent.width - Theme.space.md * 2
                spacing: Theme.space.sm

                BTextField {
                    id: password

                    width: parent.width - join.width - parent.spacing
                    password: true
                    size: "md"
                    icon: "lock"
                    placeholder: I18n.tr("Password")
                    onAccepted: join.clicked()
                    onKeyPressed: e => {
                        if (e.key === Qt.Key_Escape) {
                            list.asking = "";
                            e.accepted = true;
                        }
                    }
                }

                BButton {
                    id: join

                    size: "md"
                    variant: "primary"
                    text: I18n.tr("Connect")
                    enabled: password.text.length >= 8 || password.text.length === 5 || password.text.length === 13
                    onClicked: {
                        if (!enabled)
                            return;
                        NetworkStatus.connectWithPassword(entry.modelData, password.text);
                        password.text = "";
                        list.asking = "";
                    }
                }
            }
        }
    }
}
