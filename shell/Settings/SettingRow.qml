import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Settings.Editors

// One setting: label, description, apply-mode note, modified marker, reset
// and the editor chosen from the schema (type or explicit `editor`).
Item {
    id: row

    readonly property bool settingRow: true
    property string key: ""
    // Extra line under the description (inheritance, what the value does now).
    property string note: ""
    readonly property var def: Schema.def(key) || ({})
    readonly property bool modified: Config.isModified(key)
    // dependsOn: a bool setting that must be on; dependsOnValue: { key: value }
    // settings that must have exactly that value (e.g. only in frame layout),
    // or one of a list of values.
    readonly property bool dependencyMet: (!def.dependsOn || Config.get(def.dependsOn) === true) && Object.keys(def.dependsOnValue || {}).every(k => Array.isArray(def.dependsOnValue[k]) ? def.dependsOnValue[k].indexOf(Config.get(k)) >= 0 : Config.get(k) === def.dependsOnValue[k])
    readonly property string pending: ApplyState.status(key)
    readonly property string editorName: {
        if (def.editor)
            return def.editor;
        switch (def.type) {
        case "bool":
            return "BoolEditor";
        case "int":
        case "real":
            return "NumberEditor";
        case "enum":
            return (def.options || []).length <= 3 ? "SegmentedEditor" : "EnumEditor";
        case "color":
            return "ColorEditor";
        case "font":
            return "FontEditor";
        case "path":
            return "TextEditor";
        case "icon":
            return "IconThemeEditor";
        case "list":
            return "ListEditor";
        case "widgetLayout":
            return "WidgetLayoutEditor";
        default:
            return "TextEditor";
        }
    }
    // Compact Settings: a toggle keeps its own small width next to the text
    // instead of reserving a full editor column and stacking under it.
    readonly property bool inlineToggle: SettingsStyle.compact && editorName === "BoolEditor" && editor.item !== null
    readonly property real editorWidth: inlineToggle ? editor.item.implicitWidth : Math.max(Theme.layout.editorWidth, editor.item ? editor.item.implicitWidth : 0)
    readonly property real innerWidth: Math.max(0, width - Theme.space.xl * 2)
    // Stack before the text column becomes narrower than a normal editor.
    // Use intrinsic control widths: translated segments can exceed the token.
    readonly property bool wide: !inlineToggle && ((editor.item && editor.item.wide) || innerWidth < editorWidth + resetButton.width + Theme.space.sm + Theme.space.xl + Theme.layout.editorWidth)
    readonly property var editors: ({
            BoolEditor: boolEditor,
            NumberEditor: numberEditor,
            SegmentedEditor: segmentedEditor,
            EnumEditor: enumEditor,
            ColorEditor: colorEditor,
            FontEditor: fontEditor,
            IconThemeEditor: iconThemeEditor,
            CursorThemeEditor: cursorThemeEditor,
            ThemeEditor: themeEditor,
            WeatherLocationEditor: weatherLocationEditor,
            ListEditor: listEditor,
            ScreenListEditor: screenListEditor,
            WidgetLayoutEditor: widgetLayoutEditor,
            WallpaperEditor: wallpaperEditor,
            TextEditor: textEditor,
            ThemeModeEditor: themeModeEditor
        })

    Component { id: weatherLocationEditor; WeatherLocationEditor {} }

    Component {
        id: themeModeEditor

        ThemeModeEditor {}
    }

    Component {
        id: boolEditor

        BoolEditor {}
    }

    Component {
        id: numberEditor

        NumberEditor {}
    }

    Component {
        id: segmentedEditor

        SegmentedEditor {}
    }

    Component {
        id: enumEditor

        EnumEditor {}
    }

    Component {
        id: colorEditor

        ColorEditor {}
    }

    Component {
        id: fontEditor

        FontEditor {}
    }

    Component {
        id: iconThemeEditor

        IconThemeEditor {}
    }

    Component {
        id: cursorThemeEditor

        CursorThemeEditor {}
    }

    Component {
        id: themeEditor

        ThemeEditor {}
    }

    Component {
        id: listEditor

        ListEditor {}
    }

    Component {
        id: screenListEditor

        ScreenListEditor {}
    }

    Component {
        id: widgetLayoutEditor

        WidgetLayoutEditor {}
    }

    Component {
        id: wallpaperEditor

        WallpaperEditor {}
    }

    Component {
        id: textEditor

        TextEditor {}
    }

    width: parent ? parent.width : 0
    implicitHeight: (wide ? texts.implicitHeight + Theme.space.md + editor.height : Math.max(texts.implicitHeight, editor.height)) + Theme.space.lg * 2
    enabled: dependencyMet
    opacity: enabled ? 1 : Theme.opacity.disabled

    StateLayer {
        anchors.fill: parent
        radius: Theme.radius.md
        active: SettingsNav.highlightKey === row.key
    }

    Rectangle {
        id: marker

        visible: row.modified
        x: Theme.space.sm
        y: texts.y + (label.height - height) / 2
        width: Theme.space.xs + Theme.space.xxs
        height: width
        radius: width / 2
        color: Theme.color.accent
    }

    Column {
        id: texts
        objectName: "settingTexts"

        x: Theme.space.xl
        y: row.wide ? Theme.space.lg : (row.height - implicitHeight) / 2
        width: row.wide ? row.innerWidth : Math.max(0, row.width - editorArea.width - Theme.space.xl * 3)
        spacing: SettingsStyle.descriptionSpacing

        BText {
            id: label

            width: parent.width
            text: row.def.label || row.key
            role: "label"
            wrapMode: Text.Wrap
        }

        BText {
            width: parent.width
            visible: text !== ""
            text: row.def.description || ""
            role: "caption"
            tone: "muted"
            wrapMode: Text.Wrap
        }

        BText {
            width: parent.width
            visible: row.note !== ""
            text: row.note
            role: "caption"
            tone: "faint"
            wrapMode: Text.Wrap
        }

        BText {
            width: parent.width
            wrapMode: Text.Wrap
            visible: row.def.apply && row.def.apply !== "live"
            text: row.pending === "applied" ? (row.def.apply === "reload" ? I18n.tr("Applies after the shell reloads") : I18n.tr("Applies after the shell restarts")) : (row.pending === "reload" ? I18n.tr("Waiting for reload") : I18n.tr("Waiting for restart"))
            role: "caption"
            tone: row.pending === "applied" ? "faint" : "warning"
        }
    }

    Item {
        id: editorArea
        objectName: "settingControl"

        x: row.wide ? Theme.space.xl : row.width - width - Theme.space.xl
        y: row.wide ? texts.y + texts.implicitHeight + Theme.space.md : (row.height - height) / 2
        width: row.wide ? row.innerWidth : row.editorWidth + resetButton.width + Theme.space.sm
        height: editor.height

        Loader {
            id: editor

            anchors.left: parent.left
            width: Math.max(0, parent.width - resetButton.width - Theme.space.sm)
            height: item ? item.implicitHeight : 0
            // Editors are statically known components: Quickshell cannot load
            // qs:@ URLs of files outside the import graph.
            sourceComponent: row.editors[row.editorName] || row.editors.TextEditor
            onLoaded: {
                item.key = row.key;
            }
        }

        BIconButton {
            id: resetButton

            anchors.right: parent.right
            anchors.top: parent.top
            icon: "reset"
            size: "sm"
            opacity: row.modified ? 1 : 0
            enabled: row.modified
            onClicked: Config.reset(row.key)
        }
    }
}
