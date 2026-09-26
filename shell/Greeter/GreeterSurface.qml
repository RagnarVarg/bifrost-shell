import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Services
import qs.Shared
import "GreeterLogic.js" as Logic

// One screen of the login screen: your wallpaper (or the lock screen's
// backdrop), the lock screen's clock, and on the main screen the login card
// – picture, name, password, session – with accessibility, keyboard layout and
// power along the bottom edge. Same glass (Theme.materials.lock) and controls
// as the lock screen, so logging in looks like unlocking.
Item {
    id: surface

    required property var login
    property bool primary: true
    readonly property bool busy: login.phase === "auth" || login.phase === "launching"

    Connections {
        target: surface.login

        function onClearField() {
            field.text = "";
            field.input.forceActiveFocus();
        }
    }

    AuroraBackdrop {
        anchors.fill: parent
        mark: false
        visible: wallpaper.status !== Image.Ready
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: Wallpapers.source
        fillMode: Wallpapers.fillMode
        asynchronous: true
        visible: status === Image.Ready
    }

    // Keeps text readable over any picture.
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.visible
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Theme.palette.void, surface.login.highContrast ? 0.85 : 0.45)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Theme.palette.void, surface.login.highContrast ? 0.9 : 0.6)
            }
        }
    }

    Column {
        id: clock

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * (surface.primary ? 0.14 : 0.3)
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
            // Only over a picture: a soft shadow keeps it readable on light areas.
            layer.enabled: wallpaper.visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.palette.void
                shadowBlur: Theme.tokens.textShadow.blur
                blurMax: Theme.tokens.textShadow.blurMax
                shadowOpacity: Theme.tokens.textShadow.opacity
                shadowVerticalOffset: Theme.tokens.textShadow.offsetY
                shadowHorizontalOffset: 0
            }
        }
    }

    GlassSurface {
        id: card

        visible: surface.primary
        material: Theme.materials.lock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(clock.y + clock.height + Theme.space.xxxl, parent.height / 2 - height / 2)
        width: Theme.layout.lockCardWidth
        height: cardColumn.implicitHeight + Theme.space.xl * 2

        Column {
            id: cardColumn

            x: Theme.space.xl
            y: Theme.space.xl
            width: parent.width - Theme.space.xl * 2
            spacing: Theme.space.md

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.control.height.lg * 2
                height: width

                ClippingWrapperRectangle {
                    anchors.fill: parent
                    visible: picture.status === Image.Ready
                    radius: width / 2
                    color: "transparent"

                    Image {
                        id: picture

                        source: surface.login.userInfo.avatar ? "file://" + surface.login.userInfo.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: parent.width * 2
                        asynchronous: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: picture.status !== Image.Ready
                    radius: width / 2
                    color: Theme.color.controlFill
                    border.width: Theme.border.hairline
                    border.color: Theme.color.hairline

                    BText {
                        anchors.centerIn: parent
                        text: Logic.initials(surface.login.userInfo)
                        role: "title"
                    }
                }
            }

            BText {
                visible: surface.login.users.length <= 1
                anchors.horizontalCenter: parent.horizontalCenter
                text: surface.login.userInfo.realName || surface.login.user
                role: "heading"
            }

            BDropdown {
                visible: surface.login.users.length > 1
                width: parent.width
                model: surface.login.users.map(u => ({ value: u.name, label: u.realName || u.name }))
                currentValue: surface.login.user
                onActivated: v => surface.login.selectUser(v)
            }

            BTextField {
                id: field

                width: parent.width
                icon: "lock"
                password: surface.login.phase !== "answer"
                enabled: !surface.busy
                placeholder: surface.login.phase === "launching" ? I18n.tr("Starting %1…").arg(surface.login.sessionInfo ? surface.login.sessionInfo.name : "") : surface.busy ? I18n.tr("Checking…") : surface.login.phase === "answer" ? "" : I18n.tr("Password")
                onAccepted: t => {
                    surface.login.submit(t);
                    text = "";
                }
                Component.onCompleted: if (surface.primary)
                    input.forceActiveFocus()
            }

            Row {
                visible: surface.login.keyboard !== null && surface.login.keyboard.capsLock === true
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space.xs

                BIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "warning"
                    size: Theme.icon.size.sm
                    color: Theme.color.warning
                }

                BText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Caps Lock is on")
                    role: "caption"
                    tone: "warning"
                }
            }

            BText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: surface.login.error !== "" ? surface.login.error : surface.login.info.trim().replace(/:$/, "")
                role: "caption"
                tone: surface.login.error !== "" ? "danger" : "muted"
                wrapMode: Text.WordWrap
            }

            BDropdown {
                visible: surface.login.sessions.length > 1
                width: parent.width
                enabled: !surface.busy
                model: surface.login.sessions.map(s => ({ value: s.id, label: s.name }))
                currentValue: surface.login.session
                onActivated: v => surface.login.session = v
            }
        }
    }

    // Bottom edge: accessibility and keyboard (left), power (right), each on
    // a small pane of the card's glass so they read over any picture.
    component Pane: GlassSurface {
        default property alias content: paneRow.data

        material: Theme.materials.lock
        width: paneRow.implicitWidth + Theme.space.sm * 2
        height: paneRow.implicitHeight + Theme.space.sm * 2

        Row {
            id: paneRow

            x: Theme.space.sm
            y: Theme.space.sm
            spacing: Theme.space.xs
        }
    }

    Pane {
        visible: surface.primary
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space.xxxl

        BIconButton {
            icon: "type"
            selected: surface.login.largeText
            onClicked: surface.login.toggleLargeText()
        }

        BIconButton {
            icon: "contrast"
            selected: surface.login.highContrast
            onClicked: surface.login.toggleHighContrast()
        }

        BChip {
            visible: surface.login.keyboard !== null && surface.login.keyboard.layouts.length > 1
            anchors.verticalCenter: parent.verticalCenter
            icon: "keyboard"
            text: surface.login.keyboard ? (surface.login.keyboard.layouts[surface.login.keyboard.active] || "").toUpperCase() : ""
            onClicked: Compositor.nextKeyboardLayout()
        }
    }

    Pane {
        visible: surface.primary
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space.xxxl

        BText {
            anchors.verticalCenter: parent.verticalCenter
            visible: surface.login.armed !== ""
            text: surface.login.armed === "poweroff" ? I18n.tr("Click again to shut down") : I18n.tr("Click again to restart")
            role: "caption"
            tone: "danger"
        }

        BIconButton {
            icon: "sleep"
            onClicked: surface.login.power("suspend")
        }

        BIconButton {
            icon: "restart"
            active: surface.login.armed === "reboot"
            onClicked: surface.login.power("reboot")
        }

        BIconButton {
            icon: "power"
            active: surface.login.armed === "poweroff"
            onClicked: surface.login.power("poweroff")
        }
    }
}
