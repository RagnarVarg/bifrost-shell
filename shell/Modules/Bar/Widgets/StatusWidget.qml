import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Modules
import qs.Services
import qs.Shared

// Status icons: network, VPN, Bluetooth, volume. Each opens its own menu
// under the icon; the wheel over the volume icon changes the volume. The
// control center has its own button.
// `parts` picks the icons: the combined `status` widget shows network,
// Bluetooth and sound, the single `network`/`vpn`/`bluetooth`/`audio`
// widgets one each (WidgetHost). VPN only shows as its own widget.
BarWidget {
    id: widget

    property var parts: ["network", "bluetooth", "audio"]
    // The combined widget leaves out the parts that sit on the same bar as
    // their own widget, so no icon shows twice.
    readonly property var placedAlone: {
        if (!bar || !entry || entry.id !== "status")
            return [];
        const zones = bar.widgets || {};
        return Object.keys(zones).reduce((ids, zone) => ids.concat((zones[zone] || []).map(e => e.id)), []);
    }
    readonly property var activeParts: parts.filter(p => !placedAlone.includes(p))
    // Computed from state, not from the icons' `visible` (that follows the host).
    readonly property bool hasNetwork: activeParts.includes("network")
    readonly property bool hasVpn: activeParts.includes("vpn") && Vpn.available
    readonly property bool hasBluetooth: activeParts.includes("bluetooth") && BluetoothStatus.available
    readonly property bool hasAudio: activeParts.includes("audio")

    shown: iconCount > 0
    // Size from the state, not from the row: the host stays hidden while the
    // length is 0, and a Grid inside a hidden item doesn't lay out again, so
    // a part that becomes available later (Bluetooth, VPN) would never show.
    readonly property int iconCount: [hasNetwork, hasVpn, hasBluetooth, hasAudio].filter(Boolean).length
    readonly property real iconsLength: iconCount > 0 ? iconCount * Theme.control.height.sm + (iconCount - 1) * row.spacing : 0
    implicitWidth: vertical ? Theme.control.height.sm : iconsLength
    implicitHeight: vertical ? iconsLength : Theme.control.height.sm

    component StatusIcon: Item {
        id: status

        property string icon: ""
        property bool dim: false
        property bool strong: false         // on: full text colour instead of the icon tone
        property bool busy: false           // changing state: the icon pulses
        property bool interactive: false
        property bool selected: false
        readonly property bool hovered: mouse.containsMouse

        signal clicked
        signal wheel(var event)

        width: Theme.control.height.sm
        height: Theme.control.height.sm

        StateLayer {
            anchors.fill: parent
            radius: Theme.control.radius
            hovered: status.interactive && mouse.containsMouse
            pressed: status.interactive && mouse.pressed
            selected: status.selected
        }

        BIcon {
            id: glyph

            anchors.centerIn: parent
            name: status.icon
            size: Theme.icon.size.sm
            color: status.busy ? Theme.color.textMuted : status.dim ? Theme.color.textFaint : Theme.color.text

            SequentialAnimation on opacity {
                running: status.busy && Theme.motion.enabled
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    glyph.opacity = 1

                NumberAnimation {
                    to: 0.35
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: status.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (status.interactive)
                status.clicked()
            onWheel: w => status.wheel(w)
        }
    }

    BarRow {
        id: row

        anchors.centerIn: parent
        vertical: widget.vertical
        spacing: Theme.space.xxs

        StatusIcon {
            id: net

            visible: widget.hasNetwork
            icon: NetworkStatus.kind === "wired" ? "ethernet" : "wifi"
            dim: !NetworkStatus.connected
            interactive: true
            selected: netMenu.isOpen
            onClicked: netMenu.click()
        }

        StatusIcon {
            id: vpn

            visible: widget.hasVpn
            // Connected: a solid shield in full text colour.
            icon: Vpn.phase === "on" ? "shield-filled" : "shield"
            dim: Vpn.phase === "off"
            strong: Vpn.phase === "on"
            busy: Vpn.phase === "connecting"
            interactive: true
            selected: vpnMenu.isOpen
            onClicked: vpnMenu.click()
        }

        StatusIcon {
            id: bt

            visible: widget.hasBluetooth
            icon: "bluetooth"
            dim: !BluetoothStatus.enabled
            interactive: true
            selected: btMenu.isOpen
            onClicked: btMenu.click()
        }

        StatusIcon {
            id: vol

            visible: widget.hasAudio
            icon: Audio.muted || Audio.volume === 0 ? "volume-off" : "volume"
            interactive: true
            selected: audioMenu.isOpen
            onClicked: audioMenu.click()
            onWheel: w => Audio.adjust((w.angleDelta.y > 0 ? 1 : -1) * Config.values.controlCenter.volumeStep / 100)
        }
    }

    Connections {
        target: ShellState

        function onStatusMenuRequested(screen, menu) {
            if (!widget.bar || screen !== widget.bar.modelData.name)
                return;
            const target = ({ network: netMenu, vpn: vpnMenu, bluetooth: btMenu, audio: audioMenu })[menu];
            if (target && widget.activeParts.includes(menu))
                target.toggle();
        }
    }

    NetworkMenu {
        id: netMenu

        anchorItem: net
        bar: widget.bar
    }

    VpnMenu {
        id: vpnMenu

        anchorItem: vpn
        bar: widget.bar
    }

    BluetoothMenu {
        id: btMenu

        anchorItem: bt
        bar: widget.bar
    }

    AudioMenu {
        id: audioMenu

        anchorItem: vol
        bar: widget.bar
    }
}
