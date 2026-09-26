import QtQuick
import qs.Core
import qs.Modules
import qs.Components.Popup

// Opens a bar menu or panel once the pointer has rested on its anchor for
// bar.menus.hoverDelayMs (bar.menus.openOnHover). Shared by BarMenu and the
// control center button; closing is LeaveWatch's job.
// While another bar menu or panel is open the pointer is moving along the bar
// from one to the next (like a menu bar), so it switches without the delay.
//   HoverIntent { hovered: button.hovered; isOpen: menu.isOpen; onOpenRequested: … }
Timer {
    id: intent

    property bool hovered: false
    property bool isOpen: false
    property bool active: Config.values.bar.menus.openOnHover

    // Something opened from the bar is showing (a menu, or a bar panel).
    readonly property bool switching: PopupGroup.current !== null || ShellState.controlCenterOpen || ShellState.notificationCenterOpen

    signal openRequested

    interval: switching ? 0 : Config.values.bar.menus.hoverDelayMs
    onHoveredChanged: {
        if (hovered && active && !isOpen)
            restart();
        else
            stop();
    }
    onActiveChanged: if (!active)
        stop()
    onTriggered: if (hovered && active && !isOpen)
        openRequested()
}
