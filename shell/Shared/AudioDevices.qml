import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Services

// Audio devices to choose from, outputs or inputs (Audio: PipeWire). A click
// on a row makes it the system's default device (for every app, and it
// stays); the active one is marked. Each row mutes its device, and a
// Bluetooth device with several profiles (music quality, or headset with its
// microphone) offers them under it. Used by the control center; the list
// follows PipeWire, so devices that come and go show at once.
Column {
    id: list

    property string kind: "output"           // "output" | "input"
    readonly property bool outputs: kind === "output"
    readonly property var nodes: outputs ? Audio.sinks : Audio.sources
    readonly property var current: outputs ? Audio.sink : Audio.source

    spacing: Theme.space.xxs

    Component.onCompleted: Audio.retainDevices()
    Component.onDestruction: Audio.releaseDevices()

    BText {
        visible: list.nodes.length === 0
        width: parent.width
        text: list.outputs ? I18n.tr("No output devices") : I18n.tr("No input devices")
        role: "caption"
        tone: "faint"
    }

    Repeater {
        model: list.nodes

        delegate: Column {
            id: entry

            required property var modelData
            readonly property bool active: list.current === modelData
            readonly property bool muted: modelData.audio ? modelData.audio.muted : false
            readonly property var card: Audio.cardOf(modelData)

            width: list.width
            spacing: Theme.space.xxs

            Item {
                id: row

                width: parent.width
                height: Theme.control.height.lg

                StateLayer {
                    anchors.fill: parent
                    radius: Theme.radius.md
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                    selected: entry.active
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.outputs ? Audio.setSink(entry.modelData) : Audio.setSource(entry.modelData)
                }

                BIcon {
                    id: glyph

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    name: Audio.iconOf(entry.modelData)
                    size: Theme.icon.size.sm
                    color: entry.active ? Theme.color.text : Theme.color.iconMuted
                }

                Column {
                    anchors.left: glyph.right
                    anchors.leftMargin: Theme.space.md
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter

                    BText {
                        width: parent.width
                        text: Audio.nameOf(entry.modelData)
                        role: "label"
                        tone: entry.active ? "primary" : "muted"
                        elide: Text.ElideRight
                    }

                    BText {
                        width: parent.width
                        visible: text !== ""
                        text: [entry.active ? I18n.tr("In use") : "", entry.muted ? I18n.tr("Muted") : ""].filter(t => t).join(" · ")
                        role: "caption"
                        tone: entry.active ? "accent" : "faint"
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: actions

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xxs

                    BIconButton {
                        visible: entry.modelData.audio !== null
                        size: "sm"
                        icon: list.outputs ? (entry.muted ? "volume-off" : "volume") : (entry.muted ? "mic-off" : "mic")
                        selected: entry.muted
                        onClicked: Audio.toggleNodeMute(entry.modelData)
                    }

                    BIcon {
                        visible: entry.active
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: Theme.icon.size.sm
                        color: Theme.color.accent
                    }
                }
            }

            // Bluetooth profiles: music quality, or headset with microphone
            // (only when the device offers both).
            BSegmented {
                readonly property var choices: Audio.profileChoices(entry.card)

                visible: choices.length > 1
                width: parent.width - Theme.space.md * 2
                x: Theme.space.md
                model: choices.map(c => c.label)
                currentIndex: choices.findIndex(c => c.kind === Audio.activeChoice(entry.card))
                onActivated: i => Audio.setCardProfile(entry.card.card, choices[i].id)
            }
        }
    }
}
