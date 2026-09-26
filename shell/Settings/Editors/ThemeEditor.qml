import QtQuick
import qs.Compat
import qs.Settings
import qs.Core
import qs.Components.Controls

// Themes found in the repo and in ~/.config/bifrost/themes.
EditorBase {
    id: editor

    property var themes: []

    implicitHeight: Theme.control.height.md * 2 + Theme.space.sm

    BButton {
        anchors.bottom: parent.bottom
        width: parent.width
        text: I18n.tr("Get more themes")
        onClicked: SettingsNav.open("themeBrowser")
    }

    BDropdown {
        width: parent.width
        model: editor.themes
        currentValue: editor.value
        onActivated: v => editor.set(v)
    }

    JsonReader {
        id: reader
    }

    Component.onCompleted: Exec.run(["sh", "-c", "ls -1 \"$0\"/*.json \"$1\"/*.json 2>/dev/null", Paths.themesDir, Paths.userThemesDir], (code, out) => {
        const found = [];
        for (const file of out.split("\n").filter(f => f && !f.endsWith("/_base.json"))) {
            const res = reader.read(file);
            if (res.ok && res.data.id && !found.some(t => t.value === res.data.id))
                found.push({ value: res.data.id, label: res.data.name || res.data.id });
        }
        editor.themes = found;
    }, 0, editor)
}
