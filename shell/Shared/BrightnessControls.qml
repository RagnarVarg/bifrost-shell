import QtQuick
import qs.Core
import qs.Services
import qs.Components.Text
import qs.Components.Controls
import qs.Modules.ControlCenter

Column {
    id: controls
    property bool retained: false
    spacing: Theme.space.sm
    function sync() {
        if (visible && !retained) { retained = true; Brightness.retain(); }
        else if (!visible && retained) { retained = false; Brightness.release(); }
    }
    onVisibleChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (retained) Brightness.release()
    BText {
        width: parent.width
        text: I18n.tr("Brightness")
        role: "label"
    }
    BText {
        width: parent.width
        visible: !Brightness.available
        text: !Brightness.probed ? I18n.tr("Detecting brightness controls…") : I18n.tr("No controllable display found. Check DDC/CI in the monitor menu and I²C access on this computer.")
        wrapMode: Text.Wrap
        role: "caption"
        tone: "muted"
    }
    BButton {
        visible: !Brightness.available
        text: I18n.tr("Detect displays again")
        enabled: !Brightness.busy
        onClicked: Brightness.refresh()
    }
    Repeater {
        model: Brightness.displays
        delegate: CCSlider {
            required property var modelData
            width: controls.width
            icon: "sun"
            label: modelData.name
            value: Brightness.valueFor(modelData)
            onMoved: value => Brightness.setDisplay(modelData.id, value)
        }
    }
    BText {
        width: parent.width
        visible: Brightness.error !== ""
        text: Brightness.error
        wrapMode: Text.Wrap
        role: "caption"
        tone: "warning"
    }
}
