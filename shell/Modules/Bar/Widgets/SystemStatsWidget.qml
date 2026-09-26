import QtQuick
import qs.Core
import qs.Services
import qs.Components.Icons
import qs.Components.Text

// CPU and RAM readouts (Geist Mono), warning tone above systemStats.warnPercent.
BarWidget {
    id: widget

    readonly property var cfg: Config.values.systemStats
    readonly property real warn: cfg.warnPercent / 100

    statusGroup: true
    implicitWidth: row.implicitWidth + Theme.space.md * 2
    implicitHeight: row.implicitHeight + Theme.space.md * 2

    Component.onCompleted: SystemStats.retain()
    Component.onDestruction: SystemStats.release()

    component Readout: BarRow {
        id: readout

        property string icon: ""
        property string value: ""
        property bool warning: false

        vertical: widget.vertical
        spacing: Theme.space.xs

        BIcon {
            name: readout.icon
            size: Theme.icon.size.sm
            color: readout.warning ? Theme.color.warning : Theme.color.text
        }

        BText {
            text: widget.vertical ? readout.value.trim() : readout.value
            role: "mono"
            tone: readout.warning ? "warning" : "primary"
        }
    }

    BarRow {
        id: row

        anchors.centerIn: parent
        vertical: widget.vertical
        spacing: widget.vertical ? Theme.space.md : Theme.space.lg

        Readout {
            visible: widget.cfg.showCpu
            icon: "cpu"
            value: String(Math.round(SystemStats.cpu * 100)).padStart(2, " ") + "%"
            warning: SystemStats.cpu >= widget.warn
        }

        Readout {
            visible: widget.cfg.showRam
            icon: "memory"
            value: widget.cfg.ramUnit === "gb" ? (SystemStats.memUsedKb / 1048576).toFixed(1) + "G" : Math.round(SystemStats.mem * 100) + "%"
            warning: SystemStats.mem >= widget.warn
        }
    }
}
