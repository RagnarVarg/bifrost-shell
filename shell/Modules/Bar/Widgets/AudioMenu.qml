import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Modules.ControlCenter
import qs.Services

// Audio: volume + mute, microphone, output device.
StatusMenu {
    title: I18n.tr("Sound")

    CCSlider {
        width: parent.width
        icon: Audio.muted || Audio.volume === 0 ? "volume-off" : "volume"
        value: Audio.volume
        muted: Audio.muted
        onMoved: v => Audio.setVolume(v)
        onIconClicked: Audio.toggleMute()
    }

    CCSlider {
        visible: Audio.micAvailable
        width: parent.width
        icon: "mic"
        value: Audio.micVolume
        muted: Audio.micMuted
        onMoved: v => Audio.setMicVolume(v)
        onIconClicked: Audio.toggleMicMute()
    }

    BText {
        visible: Audio.sinks.length > 1
        text: I18n.tr("Output")
        role: "overline"
        tone: "muted"
    }

    Repeater {
        model: Audio.sinks.length > 1 ? Audio.sinks : []

        delegate: Item {
            id: sinkRow

            required property var modelData
            readonly property bool current: Audio.sink === modelData

            width: parent.width
            height: Theme.control.height.md

            StateLayer {
                anchors.fill: parent
                radius: Theme.radius.md
                hovered: mouse.containsMouse
                pressed: mouse.pressed
                selected: sinkRow.current
            }

            BIcon {
                id: mark

                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                name: sinkRow.current ? "check" : "volume"
                size: Theme.icon.size.sm
                color: sinkRow.current ? Theme.color.text : Theme.color.iconMuted
            }

            BText {
                anchors.left: mark.right
                anchors.leftMargin: Theme.space.md
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.nameOf(sinkRow.modelData)
                role: "label"
                tone: sinkRow.current ? "primary" : "muted"
                elide: Text.ElideRight
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setSink(sinkRow.modelData)
            }
        }
    }
}
