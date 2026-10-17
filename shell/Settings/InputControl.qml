import QtQuick
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.Motion
import qs.Components.Text

// Per-device row laid out like the schema Settings rows: label and
// description on the left, control on the right (stacked when narrow), and
// a reset button for a changed value shown on hover.
Item {
    id: row
    readonly property bool settingRow: true
    required property var device
    required property var definition
    readonly property var current: InputDevices.value(device, definition.key)
    readonly property bool modified: !!(InputDevices.saved[device.name] && InputDevices.saved[device.name].values[definition.key] !== undefined)
    readonly property bool isToggle: definition.type === "bool"
    readonly property real controlWidth: isToggle ? control.implicitWidth : Theme.layout.settingsEditorWidth
    readonly property bool stacked: !isToggle && width < controlWidth + reset.width + Theme.space.sm + Theme.layout.settingsEditorWidth
    width: parent.width
    readonly property real padding: SettingsStyle.grouped ? 0 : SettingsStyle.innerPadding
    height: (stacked ? texts.implicitHeight + Theme.space.md + control.height : Math.max(texts.implicitHeight, control.height)) + padding * 2 + Theme.space.sm * 2

    SettingsGroupSurface { anchors.fill:parent; visible:!SettingsStyle.grouped }

    HoverHandler { id: hover }

    Rectangle {
        visible: row.modified
        x: row.padding + texts.x - width - Theme.space.sm
        y: texts.y + (label.height - height) / 2
        width: Theme.space.xs + Theme.space.xxs
        height: width
        radius: width / 2
        color: Theme.color.accent
    }

    Column {
        id: texts
        x: row.padding + SettingsStyle.groupInset
        y: row.stacked ? row.padding + Theme.space.sm : (row.height - implicitHeight) / 2
        width: row.stacked ? row.width - x * 2 - reset.width - Theme.space.sm : Math.max(0, row.width - x * 2 - row.controlWidth - reset.width - Theme.space.sm * 2)
        spacing: SettingsStyle.descriptionSpacing
        BText { id: label; width: parent.width; text: I18n.tr(row.definition.label); role: "label"; wrapMode: Text.Wrap }
        BText {
            width: parent.width
            visible: !!row.definition.description
            text: row.definition.description ? I18n.tr(row.definition.description) : ""
            role: "caption"; tone: "muted"; wrapMode: Text.WordWrap
        }
    }

    Loader {
        id: control
        x: row.stacked ? texts.x : row.width - width - texts.x
        y: row.stacked ? texts.y + texts.implicitHeight + Theme.space.md : (row.height - height) / 2
        width: row.stacked ? row.width - texts.x * 2 : row.controlWidth
        height: item ? item.implicitHeight : 0
        sourceComponent: row.definition.type === "bool" ? toggle : row.definition.type === "enum" ? choices : number
    }

    BIconButton {
        id: reset
        x: row.stacked ? row.width - width - texts.x : control.x - width - Theme.space.sm
        y: row.stacked ? texts.y + (label.height - height) / 2 : control.y + (control.height - height) / 2
        icon: "reset"; size: "sm"
        opacity: row.modified && (hover.hovered || activeFocus) ? 1 : 0
        enabled: row.modified
        onClicked: InputDevices.reset(row.device,row.definition.key)
        Behavior on opacity { BNumberAnimation {} }
    }

    Component { id: toggle; Item { implicitWidth: toggleControl.implicitWidth; implicitHeight: Theme.control.height.md; BToggle { id: toggleControl; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: row.current === true; onToggled: value => InputDevices.set(row.device,row.definition.key,value) } } }
    Component { id: choices; BDropdown {
        model: InputDevices.choices(row.device,row.definition)
        currentValue: row.current
        placeholder: I18n.tr("Compositor default")
        onActivated: value => InputDevices.set(row.device,row.definition.key,value)
    } }
    Component { id: number; Item {
        implicitHeight: Theme.control.height.md
        BSlider {
            anchors.left: parent.left; anchors.right: valueLabel.left; anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            from: row.definition.min; to: row.definition.max
            stepSize: row.definition.step || 1
            value: Number(row.current || 0)
            onMoved: value => InputDevices.set(row.device,row.definition.key,value)
        }
        BText { id: valueLabel; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Number(row.current || 0).toFixed(row.definition.type === "int" ? 0 : 2) + (row.definition.unit ? " " + row.definition.unit : ""); role: "mono"; tone: "muted" }
    } }
}
