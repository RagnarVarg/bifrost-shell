import QtQuick
import qs.Core
import qs.Services
import qs.Components.Icons
import qs.Components.Text
import qs.Modules.Bar

BarWidget {
    id: widget
    shown: Power.hasBattery
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarButton {
        id: button
        anchors.fill: parent
        vertical: widget.vertical
        selected: menu.isOpen
        onClicked: menu.click()

        BIcon {
            name: Power.charging ? "battery-charging" : "battery-" + Math.min(4, Math.ceil(Power.charge * 4))
            color: Power.critical ? Theme.color.danger : Power.low ? Theme.color.warning : Theme.color.text
        }
        BText {
            visible: Config.get("bar.battery.showPercentage") === true
            text: Math.round(Power.charge * 100) + "%"
            role: "label"
        }
    }

    BarMenu {
        id: menu
        bar: widget.bar
        anchorItem: button
        Column {
            width: Theme.layout.editorWidth
            spacing: Theme.space.sm
            BText {
                width: parent.width
                text: Power.batteryStatus + " · " + Math.round(Power.charge * 100) + "%"
                role: "label"
                wrapMode: Text.Wrap
            }
            BText {
                width: parent.width
                visible: Power.acConnected
                text: I18n.tr("AC connected")
                role: "caption"
            }
            BText {
                width: parent.width
                visible: Power.remainingSeconds > 0
                text: I18n.tr("Estimated time: %1").arg(Media.clock(Power.remainingSeconds))
                role: "caption"
                wrapMode: Text.Wrap
            }
        }
    }
}
