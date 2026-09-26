import QtQuick
import qs.Core

// Common base for setting editors: knows its key, schema definition and
// current value, and writes through Config.
Item {
    property string key: ""
    readonly property var def: Schema.def(key) || ({})
    // The row follows its fallback no matter what is stored (a linked
    // material surface): the editor then shows the fallback as if null.
    property bool followsFallback: false
    readonly property var value: followsFallback ? null : Config.get(key)
    // Editors that need the full row width (e.g. widget layouts) set this.
    property bool wide: false
    // What a nullable setting currently resolves to while null, when the
    // page knows it better than the schema (e.g. a material's effective
    // value). Undefined = use inheritKey / inherit.
    property var fallback: undefined

    implicitWidth: Theme.layout.editorWidth
    implicitHeight: Theme.control.height.md

    // Theme token a nullable setting inherits when null (schema "inherit").
    function inherited() {
        if (fallback !== undefined)
            return fallback;
        if (def.inheritKey) {
            const v = Config.get(def.inheritKey);
            if (v !== null && v !== undefined)
                return v;
        }
        if (!def.inherit)
            return undefined;
        let node = Theme.tokens;
        for (const part of def.inherit.split("."))
            node = node ? node[part] : undefined;
        return node;
    }

    function set(v) {
        const err = Config.set(key, v);
        if (err)
            console.warn("[bifrost] settings:", err);
    }
}
