import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Text
import qs.Services
import qs.Shared

// What a locked screen shows: dark field with a faint aurora glow and the
// Bifrost mark, a large clock, and the unlock card.
Item {
    id: surface

    property var auth: null     // the Lock scope (password handling)

    AuroraBackdrop {
        anchors.fill: parent
    }

    Column {
        visible: Config.values.lock.showClock
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        spacing: Theme.space.sm

        BText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format(Time.now, Config.values.clock.format === "12h" ? "h:mm" : "HH:mm")
            role: "hero"
        }

        BText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format(Time.now, "dddd d MMMM")
            role: "heading"
            tone: "muted"
        }
    }

    GlassSurface {
        id: card

        material: Theme.materials.lock
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.58
        width: Theme.layout.lockCardWidth
        height: cardColumn.implicitHeight + Theme.space.xl * 2

        Column {
            id: cardColumn

            x: Theme.space.xl
            y: Theme.space.xl
            width: parent.width - Theme.space.xl * 2
            spacing: Theme.space.md

            BText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Platform.env("USER")
                role: "heading"
            }

            BTextField {
                id: field

                width: parent.width
                icon: "lock"
                password: true
                placeholder: surface.auth && surface.auth.busy ? I18n.tr("Checking…") : I18n.tr("Password")
                enabled: surface.auth !== null && !surface.auth.busy
                onAccepted: t => {
                    surface.auth.submit(t);
                    text = "";
                }
                Component.onCompleted: input.forceActiveFocus()
            }

            BText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: surface.auth ? surface.auth.message : ""
                role: "caption"
                tone: surface.auth && surface.auth.failed ? "danger" : "muted"
                wrapMode: Text.WordWrap
            }
        }
    }

    Row {
        visible: Config.values.lock.showMedia && Media.available
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.xxxl * 2
        spacing: Theme.space.md

        BIcon {
            name: "music"
            color: Theme.color.iconMuted
            anchors.verticalCenter: parent.verticalCenter
        }

        BText {
            text: Media.title + (Media.artist ? " · " + Media.artist : "")
            role: "label"
            tone: "muted"
            anchors.verticalCenter: parent.verticalCenter
        }

        BIconButton {
            icon: Media.playing ? "pause" : "play"
            size: "sm"
            onClicked: Media.togglePlaying()
        }
    }
}
