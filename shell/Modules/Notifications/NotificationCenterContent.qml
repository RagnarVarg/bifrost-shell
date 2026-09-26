import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import qs.Modules
import qs.Services

// The notification center: do-not-disturb, clear all, history. Shown as the
// bell's bar menu (NotificationsWidget), or in NotificationCenter's own
// window when the bar has no bell on that screen.
Item {
    id: root

    // Set by the host so the panel fits on the screen.
    property real maxHeight: 800

    implicitWidth: Theme.layout.controlCenterWidth
    implicitHeight: content.implicitHeight + Theme.space.xl * 2

    Item {
        anchors.fill: parent
        focus: ShellState.notificationCenterOpen
        Keys.onEscapePressed: ShellState.notificationCenterOpen = false
    }

    Column {
        id: content

        x: Theme.space.xl
        y: Theme.space.xl
        width: parent.width - Theme.space.xl * 2
        spacing: Theme.space.lg

        Item {
            width: parent.width
            height: Theme.control.height.md

            BText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Notifications")
                role: "title"
            }

            BButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"
                size: "sm"
                icon: "trash"
                text: I18n.tr("Clear")
                enabled: Notify.history.length > 0
                onClicked: Notify.clearAll()
            }
        }

        BListRow {
            width: parent.width
            icon: Notify.dnd ? "bell-off" : "bell"
            title: I18n.tr("Do not disturb")
            subtitle: Notify.dnd ? I18n.tr("Popups are off") : I18n.tr("Popups are shown")
            interactive: false

            BToggle {
                checked: Notify.dnd
                onToggled: c => Notify.setDnd(c)
            }
        }

        BText {
            visible: !Notify.active
            width: parent.width
            text: I18n.tr("Another shell handles notifications while Bifrost runs next to it.")
            role: "caption"
            tone: "muted"
            wrapMode: Text.WordWrap
        }

        BText {
            visible: Notify.active && Notify.history.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Theme.space.xl
            bottomPadding: Theme.space.xl
            text: I18n.tr("No notifications")
            role: "body"
            tone: "faint"
        }

        Flickable {
            id: list

            visible: Notify.history.length > 0
            width: parent.width
            height: Math.min(listColumn.implicitHeight, Math.max(0, root.maxHeight - y - Theme.space.xl * 2))
            contentHeight: listColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: listColumn

                width: list.width
                spacing: Theme.space.sm

                Repeater {
                    model: Notify.history

                    delegate: NotificationCard {
                        required property var modelData

                        width: listColumn.width
                        item: modelData
                        onCloseRequested: Notify.dismiss(modelData.id)
                    }
                }
            }

            BScrollIndicator {
                flickable: list
            }
        }
    }
}
