import QtQuick
import qs.Core
import qs.Services
import qs.Components.Text
import qs.Modules

// Time (Geist Mono readout) with optional date and ISO week; opens the clock
// menu (calendar, weather, media). On a side bar the parts are stacked:
// hours over minutes, day over month.
BarWidget {
    id: widget

    readonly property var cfg: Config.values.clock
    readonly property bool h12: cfg.format === "12h"
    readonly property string timeFormat: h12 ? (cfg.showSeconds ? "h:mm:ss AP" : "h:mm AP") : (cfg.showSeconds ? "HH:mm:ss" : "HH:mm")
    readonly property var timeLines: [h12 ? "h" : "HH", "mm"].concat(cfg.showSeconds ? ["ss"] : [], h12 ? ["AP"] : [])

    function stacked(formats) {
        return formats.map(f => Time.format(Time.now, f)).join("\n");
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarButton {
        id: button

        anchors.fill: parent
        vertical: widget.vertical
        spacing: Theme.space.md
        selected: menu.isOpen
        onClicked: menu.click()

        BText {
            visible: widget.cfg.showDate
            text: widget.vertical ? widget.stacked(["d", "MMM"]) : Time.format(Time.now, widget.cfg.dateFormat)
            horizontalAlignment: Text.AlignHCenter
            role: "label"
            tone: "primary"
        }

        BText {
            text: widget.vertical ? widget.stacked(widget.timeLines) : Time.format(Time.now, widget.timeFormat)
            horizontalAlignment: Text.AlignHCenter
            role: "readout"
        }

        BText {
            visible: widget.cfg.weekNumber
            text: "v" + Time.isoWeek(Time.now)
            role: "mono"
            tone: "primary"
        }
    }

    ClockMenu {
        id: menu

        bar: widget.bar
        anchorItem: button
    }

    Connections {
        target: ShellState

        function onStatusMenuRequested(screen, name) {
            if (name === "clock" && widget.bar && screen === widget.bar.modelData.name)
                menu.toggle();
        }
    }
}
