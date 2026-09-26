import QtQuick
import qs.Core
import qs.Components.Controls

EditorBase {
    id: editor

    implicitWidth: seg.implicitWidth
    implicitHeight: seg.implicitHeight

    BSegmented {
        id: seg

        anchors.right: parent.right
        width: Math.min(parent.width, implicitWidth)
        model: (editor.def.options || []).map(o => Schema.optionLabel(editor.key, o))
        currentIndex: (editor.def.options || []).indexOf(editor.value)
        onActivated: i => editor.set(editor.def.options[i])
    }
}
