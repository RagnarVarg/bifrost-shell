pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Translations for every user-visible string. Source strings are English;
// i18n/<lang>.json maps them to the system language:
//   { "Reload shell": "Ladda om shellet",
//     "%n change(s)": { "one": "%n ändring", "other": "%n ändringar" } }
//
// The language follows the system (LANGUAGE, LC_ALL, LC_MESSAGES, LANG, like
// gettext); Bifrost never changes it. A missing translation, or a language
// without a file, falls back to the English source. BIFROST_LANG overrides the
// language for tests.
//
//   I18n.tr("Reload shell")
//   I18n.tr("%n change(s) take effect when the shell reloads.", count)
//   I18n.tr("Keep %1?").arg(name)            (QML string .arg)
Singleton {
    id: root

    readonly property string language: detect()
    // Loaded once, on the first tr() call (the language never changes while
    // Bifrost runs), so bindings never depend on a changing table.
    property var table: ({})
    property bool loaded: false

    function detect(): string {
        const candidates = [Platform.env("BIFROST_LANG")].concat(Platform.env("LANGUAGE").split(":"), [Platform.env("LC_ALL"), Platform.env("LC_MESSAGES"), Platform.env("LANG")]);
        for (const c of candidates) {
            if (!c || c === "C" || c === "POSIX" || c.startsWith("C."))
                continue;
            return c.split(/[_.@]/)[0].toLowerCase();
        }
        return "en";
    }

    function tr(text: string, n: var): string {
        if (!loaded)
            load();
        let t = table[text];
        if (t && typeof t === "object")
            t = n === 1 ? t.one : t.other;
        if (typeof t !== "string" || t === "")
            t = text;
        return n === undefined ? t : t.replace(/%n/g, String(n));
    }

    function load() {
        loaded = true;
        if (language === "en") {
            table = {};
            return;
        }
        const res = reader.read(Paths.repoDir + "/i18n/" + language + ".json");
        table = res.ok ? res.data : {};
        if (!res.ok && !res.missing)
            console.warn("[bifrost] i18n:", res.error);
    }

    JsonReader {
        id: reader
    }
}
