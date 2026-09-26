import QtQuick
import qs.Core
import qs.Components.Controls

// Installed font families, each shown in its own face.
EditorBase {
    id: editor

    BDropdown {
        anchors.fill: parent
        searchable: true
        model: [{ value: null, label: I18n.tr("Theme (%1)").arg(editor.inherited() || "–") }].concat(Qt.fontFamilies().map(f => ({ value: f, label: f, family: f })))
        currentValue: editor.value === undefined ? null : editor.value
        onActivated: v => editor.set(v)
    }
}
