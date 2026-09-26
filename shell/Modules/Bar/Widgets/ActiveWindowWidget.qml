import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Text

// Title of the focused window on this bar's monitor. Not on a side bar: a
// title doesn't fit across it, and turned text is not wanted.
BarWidget {
    id: widget

    readonly property var win: Compositor.activeWindow
    readonly property bool show: win !== null && (!bar || !win.monitor || win.monitor === bar.modelData.name)

    shown: show && !vertical && Compositor.supports("windowList")
    implicitWidth: shown ? Math.min(title.implicitWidth, Theme.space.xxxl * 12) + Theme.space.md : 0
    implicitHeight: 0

    BText {
        id: title

        anchors.verticalCenter: parent.verticalCenter
        x: Theme.space.sm
        width: parent.width - Theme.space.md
        text: widget.win ? widget.win.title : ""
        role: "label"
        tone: "muted"
        elide: Text.ElideRight
    }
}
