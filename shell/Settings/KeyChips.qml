import QtQuick
import qs.Core
import qs.Components.Text
import "KeyNames.js" as KeyNames

// A key combination as keycaps: modifiers, then the key.
//   KeyChips { keys: "SUPER + SHIFT + code:10" }   →  [Super] [Shift] [1]
Row {
    id: root

    property string keys: ""
    property bool faint: false        // turned off / replaced

    spacing: Theme.space.xs

    Repeater {
        model: KeyNames.parts(root.keys)

        delegate: Rectangle {
            required property string modelData
            readonly property bool modifier: KeyNames.isModifier(modelData)

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(implicitHeight, label.implicitWidth + Theme.space.md * 2)
            implicitHeight: Theme.control.chip.height
            radius: Theme.radius.sm
            color: modifier ? Theme.color.controlFill : Theme.color.fieldFill
            border.width: Theme.border.hairline
            border.color: Theme.color.hairline
            opacity: root.faint ? Theme.opacity.disabled : 1

            BText {
                id: label

                anchors.centerIn: parent
                text: KeyNames.label(parent.modelData, t => I18n.tr(t))
                role: "label"
                tone: parent.modifier ? "muted" : "primary"
                font.strikeout: root.faint
            }
        }
    }
}
