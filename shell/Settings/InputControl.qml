import QtQuick
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.Text

// Per-device row using the same controls/tokens as the schema Settings rows.
Item {
    id: row
    readonly property bool settingRow: true
    required property var device
    required property var definition
    readonly property var current: InputDevices.value(device, definition.key)
    readonly property bool modified: !!(InputDevices.saved[device.name] && InputDevices.saved[device.name].values[definition.key] !== undefined)
    width: parent.width
    readonly property real padding: SettingsStyle.grouped ? 0 : SettingsStyle.innerPadding
    height: contents.implicitHeight + padding*2
    SettingsGroupSurface { anchors.fill:parent; visible:!SettingsStyle.grouped }
    Column {
    id: contents
    x:row.padding; y:row.padding
    width:Math.max(0,row.width-row.padding*2)
    spacing: SettingsStyle.descriptionSpacing
    BText { text: I18n.tr(row.definition.label); role: "label" }
    BText {
        width: parent.width
        visible: !!row.definition.description
        text: row.definition.description ? I18n.tr(row.definition.description) : ""
        role: "caption"; tone: "muted"; wrapMode: Text.WordWrap
    }
    Loader {
        width: parent.width
        sourceComponent: row.definition.type === "bool" ? toggle : row.definition.type === "enum" ? choices : number
    }
    BButton {
        visible: row.modified
        text: I18n.tr("Restore previous value"); size: "sm"; variant: "ghost"
        onClicked: InputDevices.reset(row.device,row.definition.key)
    }
    Component { id: toggle; Item { implicitHeight: control.implicitHeight; BToggle { id: control; checked: row.current === true; onToggled: value => InputDevices.set(row.device,row.definition.key,value) } } }
    Component { id: choices; BDropdown {
        model: InputDevices.choices(row.device,row.definition)
        currentValue: row.current
        placeholder: I18n.tr("Compositor default")
        onActivated: value => InputDevices.set(row.device,row.definition.key,value)
    } }
    Component { id: number; Row {
        spacing: Theme.space.md
        BSlider {
            width: Math.max(Theme.control.height.md, parent.width-valueLabel.width-parent.spacing)
            from: row.definition.min; to: row.definition.max
            stepSize: row.definition.step || 1
            value: Number(row.current || 0)
            onMoved: value => InputDevices.set(row.device,row.definition.key,value)
        }
        BText { id: valueLabel; text: Number(row.current || 0).toFixed(row.definition.type === "int" ? 0 : 2) + " " + (row.definition.unit || ""); role: "mono" }
    } }
    }
}
