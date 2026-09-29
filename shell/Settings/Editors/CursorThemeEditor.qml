import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls

// Pointer theme: the system's, or an installed XCursor theme (bifrostctl cursors list).
EditorBase {
    id: editor

    property var themes: []

    BDropdown {
        anchors.fill: parent
        searchable: true
        model: [{ value: null, label: I18n.tr("System") }].concat(editor.themes)
        currentValue: editor.value === undefined ? null : editor.value
        onActivated: v => editor.set(v)
    }

    Component.onCompleted: Ctl.run(["cursors", "list", "--json"], (ok, out, data) => {
        if (ok && data)
            editor.themes = data.map(t => ({ value: t.id, label: t.name !== t.id ? t.id + " · " + t.name : t.id }));
    }, editor)
}
