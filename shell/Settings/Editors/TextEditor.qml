import QtQuick
import qs.Core
import qs.Components.Controls

// Free text; commits on Enter or when focus leaves the field.
EditorBase {
    id: editor

    BTextField {
        id: field

        anchors.fill: parent
        text: editor.value === null || editor.value === undefined ? "" : String(editor.value)
        placeholder: editor.def.nullable ? I18n.tr("Theme") : ""
        onAccepted: t => editor.commit(t)
    }

    function commit(t) {
        set(t === "" && def.nullable ? null : t);
    }
}
