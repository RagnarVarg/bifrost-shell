import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar
import qs.Modules.Notifications
import qs.Services

// Bell with unread count (bell-off in do-not-disturb); its menu is the
// notification center, grown out of the bar like every bar menu (PanelMenu),
// opened by click, hover, IPC or keybind alike.
BarWidget {
    id: widget

    readonly property string screenName: bar ? bar.modelData.name : ""

    readonly property var anchor: ({ item: button, bar: widget.bar })

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        vertical: widget.vertical
        selected: menu.isOpen
        onClicked: menu.click()

        BIcon {
            name: Notify.dnd ? "bell-off" : "bell"
            size: Theme.icon.size.sm
            color: Theme.color.text
        }

        BText {
            visible: Notify.unread > 0
            text: Notify.unread
            role: "mono"
            tone: "accent"
        }
    }

    PanelMenu {
        id: menu

        panel: "notificationCenter"
        bar: widget.bar
        anchorItem: button
        hosting: widget.bar !== null
        panelOpen: ShellState.notificationCenterOpen && ShellState.notificationCenterScreen === widget.screenName
        onOpenRequested: ShellState.openNotificationCenter(widget.screenName, widget.anchor)
        onCloseRequested: ShellState.notificationCenterOpen = false

        NotificationCenterContent {
            width: implicitWidth
            maxHeight: widget.bar ? widget.bar.modelData.height * 0.8 : 800
        }
    }
}
