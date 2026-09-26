import QtQuick
import qs.Core
import qs.Components.Controls

// Generic list of strings: chips with remove, field to add.
EditorBase {
    id: editor

    readonly property var items: Array.isArray(value) ? value : []

    implicitHeight: flow.implicitHeight + Theme.space.sm + field.height

    Flow {
        id: flow

        width: parent.width
        spacing: Theme.space.xs
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: editor.items

            delegate: BChip {
                required property int index
                required property string modelData

                text: modelData + "  ×"
                onClicked: editor.set(editor.items.filter((_, i) => i !== index))
            }
        }
    }

    BTextField {
        id: field

        anchors.bottom: parent.bottom
        width: parent.width
        icon: "plus"
        placeholder: I18n.tr("Add")
        onAccepted: t => {
            if (t) {
                editor.set(editor.items.concat([t]));
                text = "";
            }
        }
    }
}
