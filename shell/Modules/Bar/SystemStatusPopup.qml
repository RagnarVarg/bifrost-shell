import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text
import qs.Modules
import qs.Services

// Details for the system status group: CPU usage/temp, GPU usage/temp/VRAM,
// RAM. With bar.menus.openOnHover it follows the pointer (no focus grab) and a
// click on the group runs the monitor command; without, a click opens it like
// any menu (outside click closes) and the button starts the monitor.
BarMenu {
    id: popup

    grabFocus: !Config.values.bar.menus.openOnHover
    padding: Theme.space.md

    component Line: Item {
        id: line

        property string label: ""
        property string value: ""
        property bool warn: false

        width: parent.width
        height: Theme.control.height.sm

        BText {
            anchors.verticalCenter: parent.verticalCenter
            text: line.label
            role: "caption"
            tone: "muted"
        }

        BText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: line.value
            role: "mono"
            tone: line.warn ? "warning" : "primary"
        }
    }

    component Header: Row {
        property string icon: ""
        property string title: ""

        spacing: Theme.space.sm

        BIcon {
            name: parent.icon
            size: Theme.icon.size.sm
            anchors.verticalCenter: parent.verticalCenter
        }

        BText {
            text: parent.title
            role: "label"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        readonly property real warn: Config.values.systemStats.warnPercent / 100

        width: Theme.space.xxxl * 8
        spacing: Theme.space.xxs

        Header {
            icon: "cpu"
            title: I18n.tr("Processor")
        }

        Line {
            label: I18n.tr("Usage")
            value: Math.round(SystemStats.cpu * 100) + " %"
            warn: SystemStats.cpu >= parent.warn
        }

        Line {
            visible: !isNaN(SystemStats.cpuTemp)
            label: I18n.tr("Temperature")
            value: Math.round(SystemStats.cpuTemp) + " °C"
        }

        Item {
            width: 1
            height: Theme.space.sm
        }

        Header {
            icon: "memory"
            title: I18n.tr("Memory")
        }

        Line {
            label: "RAM"
            value: (SystemStats.memUsedKb / 1048576).toFixed(1) + " / " + (SystemStats.memTotalKb / 1048576).toFixed(0) + " GB  ·  " + Math.round(SystemStats.mem * 100) + " %"
            warn: SystemStats.mem >= parent.warn
        }

        Item {
            visible: GpuStats.available
            width: 1
            height: Theme.space.sm
        }

        Header {
            visible: GpuStats.available
            icon: "display"
            title: GpuStats.name || "GPU"
        }

        Line {
            visible: GpuStats.available
            label: I18n.tr("Usage")
            value: Math.round(GpuStats.usage * 100) + " %"
            warn: GpuStats.usage >= parent.warn
        }

        Line {
            visible: GpuStats.available
            label: I18n.tr("Temperature")
            value: Math.round(GpuStats.temperature) + " °C"
        }

        Line {
            visible: GpuStats.available && GpuStats.memTotalMb > 0
            label: "VRAM"
            value: (GpuStats.memUsedMb / 1024).toFixed(1) + " / " + (GpuStats.memTotalMb / 1024).toFixed(0) + " GB"
        }

        BButton {
            visible: !Config.values.bar.menus.openOnHover && Config.values.bar.systemStatus.clickCommand !== ""
            size: "sm"
            variant: "ghost"
            icon: "open"
            text: I18n.tr("Open system monitor")
            onClicked: {
                popup.close();
                Platform.launch(["sh", "-c", Config.values.bar.systemStatus.clickCommand]);
            }
        }
    }
}
