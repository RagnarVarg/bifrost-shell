import QtQuick
import qs.Core
import qs.Components.Controls

// Toggle. A nullable bool (a per-surface override) also has an "Inherit"
// chip; while inheriting, the toggle shows the inherited state.
EditorBase {
    id: editor

    readonly property bool isNull: value === null || value === undefined
    readonly property bool effective: isNull ? inherited() === true : value === true

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.control.height.md

    Row {
        id: row

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.md

        BChip {
            visible: editor.def.nullable === true
            anchors.verticalCenter: parent.verticalCenter
            text: editor.def.nullLabel ? I18n.tr(editor.def.nullLabel) : I18n.tr("Inherit")
            selected: editor.isNull
            onClicked: editor.set(null)
        }

        BToggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: editor.effective
            opacity: editor.isNull && editor.def.nullable ? Theme.opacity.disabled + (1 - Theme.opacity.disabled) / 2 : 1
            onToggled: c => editor.set(c)
        }
    }
}
