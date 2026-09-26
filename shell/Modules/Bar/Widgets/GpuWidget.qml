import QtQuick
import qs.Core
import qs.Services
import qs.Components.Icons
import qs.Components.Text

// GPU temperature / usage. Hidden when no GPU source is available.
BarWidget {
    id: widget

    readonly property string show: Config.values.gpu.show
    readonly property real warn: Config.values.systemStats.warnPercent / 100
    readonly property var parts: [show !== "usage" ? Math.round(GpuStats.temperature) + "°" : "", show !== "temp" ? Math.round(GpuStats.usage * 100) + "%" : ""].filter(s => s)

    shown: GpuStats.available
    statusGroup: true
    implicitWidth: GpuStats.available ? row.implicitWidth + Theme.space.md * 2 : 0
    implicitHeight: GpuStats.available ? row.implicitHeight + Theme.space.md * 2 : 0

    Component.onCompleted: GpuStats.retain()
    Component.onDestruction: GpuStats.release()

    BarRow {
        id: row

        anchors.centerIn: parent
        vertical: widget.vertical
        spacing: Theme.space.xs

        BIcon {
            name: "display"
            size: Theme.icon.size.sm
            color: GpuStats.usage >= widget.warn ? Theme.color.warning : Theme.color.text
        }

        // Temperature and usage side by side, stacked on a side bar.
        Repeater {
            model: widget.vertical ? widget.parts : [widget.parts.join("  ")]

            delegate: BText {
                required property string modelData

                role: "mono"
                tone: GpuStats.usage >= widget.warn ? "warning" : "primary"
                text: modelData
            }
        }
    }
}
