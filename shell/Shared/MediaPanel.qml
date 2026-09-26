import QtQuick
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text

Item {
    id: panel
    implicitHeight: mediaRow.y + mediaRow.implicitHeight + Theme.space.md

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.md
        color: Theme.color.controlFill
    }

    BDropdown {
        id: playerSelector
        x: Theme.space.md
        y: Theme.space.md
        width: parent.width - Theme.space.md * 2
        visible: Media.players.length > 1
        model: Media.players.map(p => ({value:p.dbusName,label:p.identity}))
        currentValue: Media.player ? Media.player.dbusName : ""
        onActivated: name => Media.selectPlayer(name)
    }

    Row {
        id: mediaRow

        x: Theme.space.md
        y: playerSelector.visible ? playerSelector.y+playerSelector.height+Theme.space.sm : Theme.space.md
        width: parent.width - Theme.space.md * 2
        spacing: Theme.space.md

        Item {
            id: cover

            width: Theme.control.height.lg + Theme.space.md
            height: width

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.sm
                color: Theme.color.surfaceRaised
                visible: art.status !== Image.Ready
            }

            BIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "music"
                size: Theme.icon.size.lg
                color: Theme.color.iconMuted
            }

            Image {
                id: art

                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Column {
            width: parent.width - cover.width - controls.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.xxs

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

            Item {
                visible: Media.length > 0
                width: parent.width
                height: Theme.control.slider.track + Theme.space.sm * 2 + elapsed.implicitHeight

                Rectangle {
                    id: track

                    y: Theme.space.sm
                    width: parent.width
                    height: Theme.control.slider.track
                    radius: height / 2
                    color: Theme.color.track

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Media.position / Math.max(1, Media.length)))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.color.trackActive
                    }
                }

                BText {
                    id: elapsed

                    anchors.top: track.bottom
                    anchors.topMargin: Theme.space.xs
                    text: Media.clock(Media.position)
                    role: "mono"
                    tone: "faint"
                }

                BText {
                    anchors.top: track.bottom
                    anchors.topMargin: Theme.space.xs
                    anchors.right: parent.right
                    text: Media.clock(Media.length)
                    role: "mono"
                    tone: "faint"
                }
            }
        }

        Row {
            id: controls

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.xxs

            BIconButton {
                icon: "previous"
                enabled: Media.canPrevious
                onClicked: Media.previous()
            }

            BIconButton {
                icon: Media.playing ? "pause" : "play"
                enabled: Media.canToggle
                active: Media.playing
                onClicked: Media.togglePlaying()
            }

            BIconButton {
                icon: "next"
                enabled: Media.canNext
                onClicked: Media.next()
            }
        }
    }
}
