import QtQuick
import qs.Core
import qs.Components.Controls

EditorBase {
    id: editor

    BDropdown {
        anchors.fill: parent
        model: (editor.def.options || []).map(o => ({ value: o, label: Schema.optionLabel(editor.key, o) }))
        currentValue: editor.value
        onActivated: v => editor.set(v)
    }
}
