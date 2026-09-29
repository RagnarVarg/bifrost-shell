import QtQuick
import qs.Core
import qs.Services
import qs.Components.Text
import qs.Components.Controls
import qs.Modules.ControlCenter

// Brightness sliders, one per controllable display. `compact` (control
// center): only when a display has a working slider, nothing at all
// otherwise; the full form (Settings → Displays) also explains why there is
// none and can detect again. The column stays visible either way, so it
// keeps looking for displays while shown.
Column {
    id: controls
    property bool compact: false
    readonly property bool diagnostics: !compact
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
        visible: controls.diagnostics || Brightness.available
        text: I18n.tr("Brightness")
        role: "label"
    }
    BText {
        width: parent.width
        visible: controls.diagnostics && !Brightness.available
        text: !Brightness.probed ? I18n.tr("Detecting brightness controls…") : I18n.tr("No controllable display found. Check DDC/CI in the monitor menu and I²C access on this computer.")
        wrapMode: Text.Wrap
        role: "caption"
        tone: "muted"
    }
    Repeater {
        model: controls.diagnostics ? Brightness.unavailableDisplays : []
        delegate: BText {
            required property var modelData
            width: controls.width
            text: modelData.name + " · " + I18n.tr("Brightness control unavailable over DDC/CI")
            wrapMode: Text.Wrap
            role: "caption"
            tone: "muted"
        }
    }
    BButton {
        visible: controls.diagnostics && !Brightness.available
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
        visible: Brightness.error !== "" && (controls.diagnostics || Brightness.available)
        text: Brightness.error
        wrapMode: Text.Wrap
        role: "caption"
        tone: "warning"
    }
}
