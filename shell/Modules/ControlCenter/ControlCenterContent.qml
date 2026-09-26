import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text
import qs.Modules
import qs.Services
import qs.Shared

// What the control center shows, wherever it opens (Placement): as a bar
// menu grown out of the bar (ControlCenterWidget), in its own window when the
// bar has no control center button, or grown out of the dock.
Item {
    id: center

    readonly property var cfg: Config.values.controlCenter
    readonly property string detail: ShellState.controlCenterDetail
    readonly property bool open: ShellState.controlCenterOpen

    function close() {
        ShellState.controlCenterOpen = false;
    }

    function uptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + " d " : "") + (h > 0 ? h + " h " : "") + m + " min";
    }

    implicitWidth: Theme.layout.controlCenterWidth
    implicitHeight: column.implicitHeight + Theme.space.xl * 2

    Item {
        anchors.fill: parent
        focus: center.open
        Keys.onEscapePressed: center.close()
    }

    Column {
        id: column

        x: Theme.space.xl
        y: Theme.space.xl
        width: parent.width - Theme.space.xl * 2
        spacing: Theme.space.lg

        // System status
        Item {
            visible: center.cfg.showSystem
            width: parent.width
            height: sysColumn.implicitHeight

            Column {
                id: sysColumn

                width: parent.width - actions.width - Theme.space.md
                spacing: Theme.space.xs

                BText {
                    text: I18n.tr("Uptime %1").arg(center.uptime(SystemStats.uptimeSeconds))
                    role: "label"
                }

                Row {
                    spacing: Theme.space.lg

                    BText {
                        text: "CPU " + Math.round(SystemStats.cpu * 100) + "%"
                        role: "mono"
                        tone: "muted"
                    }

                    BText {
                        text: "RAM " + (SystemStats.memUsedKb / 1048576).toFixed(1) + "/" + (SystemStats.memTotalKb / 1048576).toFixed(0) + " G"
                        role: "mono"
                        tone: "muted"
                    }

                    BText {
                        visible: GpuStats.available
                        text: "GPU " + Math.round(GpuStats.temperature) + "°"
                        role: "mono"
                        tone: "muted"
                    }
                }
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xs

                BIconButton {
                    icon: "tune"
                    onClicked: {
                        center.close();
                        Launch.openSettings("controlCenter");
                    }
                }
            }
        }

        BDivider {
            visible: center.cfg.showSystem
            width: parent.width
        }

        // Tiles
        Grid {
            id: tiles

            width: parent.width
            columns: 2
            columnSpacing: Theme.space.md
            rowSpacing: Theme.space.md

            readonly property real tileWidth: (width - columnSpacing) / 2

            CCTile {
                width: tiles.tileWidth
                icon: NetworkStatus.kind === "wired" ? "ethernet" : "wifi"
                title: I18n.tr("Network")
                status: NetworkStatus.label
                on: NetworkStatus.connected
                expandable: NetworkStatus.hasWifi
                expanded: center.detail === "wifi"
                onExpand: ShellState.controlCenterDetail = center.detail === "wifi" ? "" : "wifi"
                onClicked: if (NetworkStatus.hasWifi)
                    NetworkStatus.setWifiEnabled(!NetworkStatus.wifiEnabled)
            }

            // Turning Bluetooth off while BT keyboards/mice are connected
            // needs a second click: it would disconnect the user's input.
            CCTile {
                id: btTile

                property bool armed: false

                width: tiles.tileWidth
                icon: "bluetooth"
                title: "Bluetooth"
                status: armed ? I18n.tr("Click again: disconnects %1").arg(BluetoothStatus.inputDevices.map(d => d.name).join(", ")) : BluetoothStatus.label
                on: BluetoothStatus.enabled
                enabled: BluetoothStatus.available
                expandable: true
                expanded: center.detail === "bluetooth"
                onExpand: ShellState.controlCenterDetail = center.detail === "bluetooth" ? "" : "bluetooth"
                onClicked: {
                    if (BluetoothStatus.enabled && BluetoothStatus.inputDevices.length > 0 && !armed) {
                        armed = true;
                        disarmBt.restart();
                        return;
                    }
                    armed = false;
                    BluetoothStatus.setEnabled(!BluetoothStatus.enabled);
                }

                Timer {
                    id: disarmBt

                    interval: 4000
                    onTriggered: btTile.armed = false
                }
            }

            CCTile {
                visible: Vpn.available
                width: tiles.tileWidth
                icon: "shield"
                title: "VPN"
                status: Vpn.connected ? Vpn.detail : I18n.tr("Disconnected")
                on: Vpn.connected
                busy: Vpn.busy
                onClicked: Vpn.toggle()
            }

            CCTile {
                width: tiles.tileWidth
                icon: Notify.dnd ? "bell-off" : "bell"
                title: I18n.tr("Do not disturb")
                status: Notify.dnd ? I18n.tr("On") : I18n.tr("Off")
                on: Notify.dnd
                onClicked: Notify.setDnd(!Notify.dnd)
            }

            CCTile {
                visible: Audio.micAvailable
                width: tiles.tileWidth
                icon: Audio.micMuted ? "mic-off" : "mic"
                title: I18n.tr("Microphone")
                status: Audio.micMuted ? I18n.tr("Muted") : I18n.tr("On")
                on: !Audio.micMuted
                expandable: true
                expanded: center.detail === "input"
                onExpand: ShellState.controlCenterDetail = center.detail === "input" ? "" : "input"
                onClicked: Audio.toggleMicMute()
            }
        }

        // Wi-Fi networks (expanded from the network tile)
        Loader {
            width: parent.width
            active: center.detail === "wifi"
            visible: active

            sourceComponent: Column {
                spacing: Theme.space.sm
                WifiNetworks { width: parent.width }
                BButton {
                    size: "sm"
                    variant: "ghost"
                    icon: "tune"
                    text: I18n.tr("Network settings")
                    onClicked: {
                        center.close();
                        Launch.openSettings("network");
                    }
                }
            }
        }

        // Bluetooth devices (expanded from the tile)
        Loader {
            width: parent.width
            active: center.detail === "bluetooth"
            visible: active

            sourceComponent: Column {
                spacing: Theme.space.sm

                BluetoothDevices {
                    width: parent.width
                    compact: true
                }

                BButton {
                    size: "sm"
                    variant: "ghost"
                    icon: "tune"
                    text: I18n.tr("Bluetooth settings")
                    onClicked: {
                        center.close();
                        Launch.openSettings("bluetooth");
                    }
                }
            }
        }

        // Power profile
        Column {
            visible: Power.available && Power.profiles.length > 1
            width: parent.width
            spacing: Theme.space.sm

            readonly property var names: ({
                    "power-saver": I18n.tr("Power saver"),
                    "balanced": "Balanserad",
                    "performance": "Prestanda"
                })

            BText {
                text: I18n.tr("Power profile")
                role: "overline"
                tone: "muted"
            }

            BSegmented {
                width: parent.width
                model: Power.profiles.map(p => parent.names[p] || p)
                currentIndex: Power.profiles.indexOf(Power.profile)
                onActivated: i => Power.set(Power.profiles[i])
            }
        }

        BDivider {
            width: parent.width
        }

        // Sliders
        CCSlider {
            visible: Audio.available
            width: parent.width
            icon: Audio.muted || Audio.volume === 0 ? "volume-off" : "volume"
            label: Audio.sinkName
            value: Audio.volume
            muted: Audio.muted
            expandable: true
            expanded: center.detail === "output"
            onExpand: ShellState.controlCenterDetail = center.detail === "output" ? "" : "output"
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
        }

        // Output devices (expanded from the volume slider's device name)
        Loader {
            width: parent.width
            active: center.detail === "output"
            visible: active

            sourceComponent: AudioDevices {
                kind: "output"
            }
        }

        // The microphone: always while its devices are open, else by setting.
        CCSlider {
            visible: (center.cfg.showMicrophone || center.detail === "input") && Audio.micAvailable
            width: parent.width
            icon: Audio.micMuted ? "mic-off" : "mic"
            label: Audio.nameOf(Audio.source)
            value: Audio.micVolume
            muted: Audio.micMuted
            expandable: true
            expanded: center.detail === "input"
            onExpand: ShellState.controlCenterDetail = center.detail === "input" ? "" : "input"
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()
        }

        // Input devices (expanded from the microphone slider or tile)
        Loader {
            width: parent.width
            active: center.detail === "input"
            visible: active

            sourceComponent: AudioDevices {
                kind: "input"
            }
        }

        BrightnessControls {
            width: parent.width
        }

        // Media
        Item {
            visible: center.cfg.showMedia && Media.available
            width: parent.width
            height: Theme.control.height.lg + Theme.space.md

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.lg
                color: Theme.color.controlFill
                border.width: Theme.border.hairline
                border.color: Theme.color.hairline
            }

            BIcon {
                id: note

                anchors.left: parent.left
                anchors.leftMargin: Theme.space.lg
                anchors.verticalCenter: parent.verticalCenter
                name: "music"
                color: Theme.color.iconMuted
            }

            Column {
                anchors.left: note.right
                anchors.leftMargin: Theme.space.md
                anchors.right: controls.left
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                BText {
                    width: parent.width
                    text: Media.title
                    role: "label"
                    elide: Text.ElideRight
                }

                BText {
                    width: parent.width
                    visible: text !== ""
                    text: Media.artist
                    role: "caption"
                    tone: "muted"
                    elide: Text.ElideRight
                }
            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter

                BIconButton {
                    icon: "previous"
                    size: "sm"
                    onClicked: Media.previous()
                }

                BIconButton {
                    icon: Media.playing ? "pause" : "play"
                    size: "sm"
                    onClicked: Media.togglePlaying()
                }

                BIconButton {
                    icon: "next"
                    size: "sm"
                    onClicked: Media.next()
                }
            }
        }
    }
}
