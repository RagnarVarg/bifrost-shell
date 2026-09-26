pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import "ThemeLogic.js" as T

// Central design tokens. Built from themes/_base.json → theme chain (via
// `extends`) → variant (dark/light) → appearance settings.
//
// Components use only these tokens, never literal colours or sizes:
//   Theme.color.text, Theme.space.md, Theme.radius.lg, Theme.materials.panel,
//   Theme.motion.duration.normal, Theme.motion.curve.standard, Theme.states.selected …
//
// Every surface uses a material from Theme.materials (one glass system), and
// interaction states use Theme.states, whose `fill` is "solid", "prism" or
// "ring". Prism is the Bifrost refraction look; a later shader only has to be
// added to the shared state-layer component, not to each component.
Singleton {
    id: root

    readonly property var appearance: Config.values.appearance || ({})
    readonly property string themeId: appearance.theme || "bifrost-graphite"
    // Light or dark comes from appearance.mode through ThemeMode (fixed,
    // system preference, or sunrise/sunset).
    readonly property string variant: ThemeMode.variant

    property var tokens: ({})
    property var issues: []
    property var chainIds: []
    property int revision: 0

    readonly property var palette: tokens.palette || ({})
    readonly property var color: tokens.color || ({})
    readonly property var space: tokens.space || ({})
    readonly property var radius: tokens.radius || ({})
    // Shared with bifrostctl's compositor rounding calculation.
    readonly property real windowRadius: Math.max(0, Math.round(Config.get("hyprland.rounding") ?? radius.lg ?? 0))
    readonly property var border: tokens.border || ({})
    readonly property var opacity: tokens.opacity || ({})
    readonly property var elevation: tokens.elevation || ({})
    readonly property var motion: tokens.motion || ({})
    readonly property var font: tokens.font || ({})
    readonly property var glass: tokens.glass || ({})
    readonly property var materials: tokens.materials || ({})
    readonly property var prism: tokens.prism || ({})
    readonly property var states: tokens.states || ({})
    readonly property var typography: tokens.typography || ({})
    readonly property var icon: tokens.icon || ({})
    readonly property var control: tokens.control || ({})
    readonly property var layout: tokens.layout || ({})
    // Active density factors { name, space, control, icon, panel }.
    readonly property var density: tokens.densityFactors || ({ name: "standard", space: 1, control: 1, icon: 1, panel: 1 })

    function alpha(c: color, a: real): color {
        return Qt.alpha(c, a);
    }

    function material(name: string): var {
        return materials[name] || materials.panel || ({});
    }

    // User themes (~/.config/bifrost/themes) take precedence over repo themes.
    function findTheme(id) {
        for (const dir of [Paths.userThemesDir, Paths.themesDir]) {
            const res = reader.read(dir + "/" + id + ".json");
            if (res.ok || !res.missing)
                return res;
        }
        return { ok: false, missing: true, error: "theme '" + id + "' not found" };
    }

    function loadChain(id) {
        const chain = [];
        const errs = [];
        const seen = {};
        let next = id;
        while (next && !seen[next]) {
            seen[next] = true;
            const res = findTheme(next);
            if (!res.ok) {
                errs.push(res.error);
                break;
            }
            chain.unshift(res.data);
            next = res.data.extends || (next === "_base" ? "" : "_base");
        }
        return { chain: chain, errors: errs };
    }

    function rebuild() {
        let loaded = loadChain(themeId);
        let errs = loaded.errors;
        if (errs.length && themeId !== "bifrost-graphite") {
            loaded = loadChain("bifrost-graphite");
            errs = errs.concat(["falling back to bifrost-graphite"], loaded.errors);
        }
        const res = T.build(loaded.chain, variant, appearance, Config.values.materials || ({}));
        chainIds = loaded.chain.map(t => t.id);
        tokens = res.tokens;
        issues = errs.concat(res.issues);
        revision++;
        for (const i of issues)
            console.warn("[bifrost] theme:", i);
    }

    Connections {
        target: Config

        function onSettingChanged(key, value) {
            if (key.startsWith("appearance.") || key.startsWith("materials."))
                rebuildLater.restart();
        }
    }

    onVariantChanged: rebuildLater.restart()

    // Coalesces bursts of changes (e.g. a slider drag) into one rebuild.
    Timer {
        id: rebuildLater

        interval: 0
        onTriggered: root.rebuild()
    }

    WatchedFile {
        path: Paths.userThemesDir + "/" + root.themeId + ".json"
        onContentChanged: rebuildLater.restart()
    }

    JsonReader {
        id: reader
    }

    Component.onCompleted: rebuild()
}
