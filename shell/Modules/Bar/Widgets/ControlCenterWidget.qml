import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Modules
import qs.Modules.Bar
import qs.Modules.ControlCenter

// Opens the control center (quick system controls). With
// controlCenter.placement "bar" (Top panel) it is this button's bar menu,
// grown out of the bar like the other menus (MenuHost: one glass with the
// bar, hover switching, leave and outside-click closing). The menu and
// ShellState.controlCenterOpen follow each other (PanelMenu), so IPC and
// keybinds open the same menu. Placed on the dock, a click opens it there
// (ControlCenter).
BarWidget {
    id: widget

    readonly property string screenName: bar ? bar.modelData.name : ""
    readonly property var anchor: ({ item: button, bar: widget.bar })
    readonly property bool hosts: Placement.controlCenter === "bar" && widget.bar !== null
    readonly property bool openHere: ShellState.controlCenterOpen && ShellState.controlCenterScreen === screenName

    implicitWidth: button.implicitWidth

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        selected: menu.isOpen || widget.openHere
        onClicked: {
            if (widget.hosts)
                menu.click();
            else
                ShellState.toggleControlCenter(widget.screenName, widget.anchor);
        }

        BIcon {
            name: "toggles"
            size: Theme.icon.size.md
            color: Theme.color.text
        }
    }

    PanelMenu {
        id: menu

        panel: "controlCenter"
        bar: widget.bar
        anchorItem: button
        hosting: widget.hosts
        panelOpen: widget.openHere
        onOpenRequested: byHover => ShellState.openControlCenter(widget.screenName, widget.anchor, byHover)
        onCloseRequested: ShellState.controlCenterOpen = false

        ControlCenterContent {
            width: implicitWidth
        }
    }
}
