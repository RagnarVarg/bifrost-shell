//@ pragma AppId bifrost.selftest

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Compat
import qs.Compositor
import qs.Core
// Quickshell only registers qs.* modules that the entry file imports, so every
// module used by dynamically created components must be listed here.
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text
import qs.Components.Popup
import qs.Modules
import qs.Modules.Bar
import qs.Modules.Bar.Widgets
import qs.Modules.ControlCenter
import qs.Modules.Dock
import qs.Modules.Launcher
import qs.Modules.Launcher.Providers
import qs.Modules.Lock
import qs.Modules.Notifications
import qs.Modules.Osd
import qs.Modules.PowerMenu
import qs.Modules.Prompt
import qs.Modules.Bluetooth
import qs.Modules.Idle
import qs.Greeter
import qs.Modules.Wallpaper
import qs.Services
import qs.Shared
import qs.Settings
import qs.Settings.Editors
import "Core/ConfigLogic.js" as L
import "Core/ThemeLogic.js" as ThemeLogic
import "Compat/Version.js" as V
import "Core/Sun.js" as Sun
import "Core/Migrations.js" as Migrations
import "Shared/WorkspaceMap.js" as WorkspaceMap
import "Modules/Dock/DockModel.js" as DockModel
import "Modules/Overview/OverviewLayout.js" as OverviewLayout
import "Compositor/Minimize.js" as Minimize
import "Modules/Dock/DockGeometry.js" as DockGeometry
import "Settings/KeyNames.js" as KeyNames
import "Greeter/GreeterLogic.js" as GreeterLogic
import "Shared/GlassJoin.js" as GlassJoin

// Core selftest. Run via scripts/selftest.sh, which points BIFROST_CONFIG_DIR
// at a throwaway directory — never run this against ~/.config/bifrost.
// Prints "PASS …"/"FAIL …" lines and finally "SELFTEST DONE pass=N fail=M".
ShellRoot {
    id: test

    property int passed: 0
    property int failed: 0
    property var hoverCase: null
    property bool optionalPending: true
    property bool finishPending: false
    property bool stdinPending: true

    function check(name, cond, detail) {
        if (cond) {
            passed++;
            console.info("PASS", name);
        } else {
            failed++;
            console.info("FAIL", name + (detail !== undefined ? ": " + JSON.stringify(detail) : ""));
        }
    }

    function eq(name, actual, expected) {
        check(name, L.equals(actual, expected), { actual: actual, expected: expected });
    }

    function readConfigFile() {
        Config.flush();
        const res = reader.read(Paths.configFile);
        return res.ok ? res.data : null;
    }

    function testLogic() {
        const o = {};
        L.deepSet(o, "a.b.c", 1);
        L.deepSet(o, "a.d", 2);
        eq("logic.deepGet", L.deepGet(o, "a.b.c"), 1);
        L.deepDelete(o, "a.b.c");
        eq("logic.deepDelete prunes empty parents", o, { a: { d: 2 } });
        eq("logic.merge deep", L.merge({ a: { x: 1, y: 2 } }, { a: { y: 3 } }), { a: { x: 1, y: 3 } });
        eq("logic.merge leaf replaces", L.merge({ w: { l: [1], r: [2] } }, { w: { l: [3] } }, { w: true }), { w: { l: [3] } });

        const intDef = { key: "k", type: "int", min: 0, max: 10 };
        eq("coerce int clamps", L.coerce(intDef, 99).value, 10);
        eq("coerce int from string", L.coerce(intDef, "7").value, 7);
        check("coerce int rejects text", !L.coerce(intDef, "abc").ok);
        check("coerce null rejected when not nullable", !L.coerce(intDef, null).ok);
        check("coerce null ok when nullable", L.coerce({ key: "k", type: "real", nullable: true }, null).ok);
        check("coerce enum", L.coerce({ key: "k", type: "enum", options: ["a"] }, "a").ok && !L.coerce({ key: "k", type: "enum", options: ["a"] }, "b").ok);
        check("coerce color", L.coerce({ key: "k", type: "color" }, "#A1B2C3").ok && !L.coerce({ key: "k", type: "color" }, "red").ok);
        check("coerce list", L.coerce({ key: "k", type: "list" }, ["a"]).ok && !L.coerce({ key: "k", type: "list" }, "a").ok);
        eq("unknownKeys", L.unknownKeys({ bar: { height: 1, nope: 2 }, zzz: 1 }, { "bar.height": {} }, ""), ["bar.nope", "zzz"]);
        eq("resolveRefs", L.resolveRefs({ a: "@b.c", b: { c: "@d" }, d: 5 }, { a: "@b.c", b: { c: "@d" }, d: 5 }).a, 5);
        eq("resolveRefs cycle terminates", typeof L.resolveRefs("@x", { x: "@x" }), "string");

        check("version compare", V.atLeast("0.56.2", "0.55.0") && !V.atLeast("0.54.9", "0.55.0") && V.atLeast("v0.56.2-dirty", "0.56.2"));
    }

    function testSchema() {
        check("schema ready", Schema.ready);
        eq("schema has no errors", Schema.errors, []);
        check("schema has keys", Schema.keys.length > 20, Schema.keys.length);
        check("every setting has a label", Schema.keys.every(k => !!Schema.entries[k].label));
        eq("i18n falls back to English source", I18n.tr("Reload shell"), "Reload shell");
        eq("i18n plural source", I18n.tr("%n devices", 3), "3 devices");
        check("search finds bar height", Schema.search("height").some(r => r.key === "bar.height"));
        eq("hyprland section support follows compositor", Schema.isSupported("hyprland.gapsIn"), Compositor.kind === "hyprland");
        check("deps manifest loaded", Deps.min("hyprland") !== "" && Deps.feature("hyprland", "hyprctlEval") !== "");
    }

    function testMigrations() {
        const v1 = { version: 1, appearance: { icons: {} }, values: { appearance: { variant: "light", transparency: { bar: 40, windows: 20 }, glass: { grain: 0.03, blur: false }, borders: { enabled: false }, shadows: { enabled: false } }, bar: { radius: 6, height: 40 }, hyprland: { blur: { size: 20, passes: 6 }, gapsIn: 4 } } };
        const out = Migrations.migrate(JSON.parse(JSON.stringify(v1)), Config.formatVersion);
        eq("migrated version", out.version, Config.formatVersion);
        eq("variant → mode", out.values.appearance.mode, "light");
        check("stray top-level appearance dropped", out.appearance === undefined);
        eq("old glass settings → one glass (blur off and border off kept)", out.values.materials, { blur: 0, border: false });
        const v4 = { version: 4, values: { materials: { blurStrength: 49, bar: { blur: true }, dock: { blur: false }, osd: { transparency: 10 } } } };
        eq("4 → 6: the old blur strength becomes the one blur", Migrations.migrate(v4, Config.formatVersion).values.materials, { blur: 49 });
        const v5 = { version: 5, values: {
            materials: { link: true, unlinked: ["dock"], all: { transparency: 44, blur: 22, tint: "#0F1516", thickness: 0, glow: 0.25, borderWidth: 0.5 }, dock: { transparency: 100 } },
            appearance: { prism: { enabled: false, intensity: 2 }, spacingScale: 1.5, radiusScale: 2 },
            hyprland: { windows: { activeTransparency: 10, inactiveTransparency: 20 }, gapsIn: 3 },
            settingsUI: { layout: "boxed" } } };
        const v6 = { version: 6, values: { appearance: { accent: "#123456" }, materials: { tint: "#0F1516", blur: 5 } } };
        const out7 = Migrations.migrate(v6, Config.formatVersion).values;
        eq("6 → 7: one accent and tint become the same colour in light and dark", [out7.appearance.accent, out7.materials.tint], [{ light: "#123456", dark: "#123456" }, { light: "#0F1516", dark: "#0F1516" }]);
        const out6 = Migrations.migrate(v5, Config.formatVersion).values;
        eq("5 → 6: All surfaces' glass is kept, per-surface and link settings are dropped", out6.materials, { transparency: 44, blur: 22, tint: { light: "#0F1516", dark: "#0F1516" } });
        eq("5 → 6: prism switch off → intensity 0; spacing scale → density", [out6.appearance.prism, out6.appearance.density, out6.appearance.spacingScale, out6.appearance.radiusScale], [{ intensity: 0 }, "spacious", undefined, 2]);
        eq("5 → 6: app window transparency and the Settings layout page removed", [out6.hyprland, out6.settingsUI], [{ gapsIn: 3 }, undefined]);
        check("old keys removed", out.values.appearance.transparency === undefined && out.values.bar.radius === undefined && out.values.hyprland.blur === undefined && out.values.hyprland.gapsIn === 4);
    }

    function testSun() {
        const st = Sun.parseIso6709("+5920+01803");
        check("zone1970 coordinates parse", Math.abs(st.lat - 59.333) < 0.01 && Math.abs(st.lon - 18.05) < 0.01, JSON.stringify(st));
        const t = Sun.times(new Date(Date.UTC(2026, 8, 25, 12)), st.lat, st.lon);
        const utcMin = d => d.getUTCHours() * 60 + d.getUTCMinutes();
        // Stockholm 2026-09-25: sunrise 04:39 UTC, sunset 16:39 UTC (checked against an
        // independent solar-elevation computation; ±3 min)
        check("sunrise Stockholm", Math.abs(utcMin(t.sunrise) - 279) <= 3, t.sunrise.toISOString());
        check("sunset Stockholm", Math.abs(utcMin(t.sunset) - 999) <= 3, t.sunset.toISOString());
        const k = Sun.parseIso6709("+6751+02014");
        eq("polar day in Kiruna at midsummer", Sun.times(new Date(Date.UTC(2026, 5, 21, 12)), k.lat, k.lon).polar, "day");
        eq("polar night in Kiruna at midwinter", Sun.times(new Date(Date.UTC(2026, 11, 21, 12)), k.lat, k.lon).polar, "night");
        const noon = new Date(Date.UTC(2026, 8, 25, 11));
        check("daylight at noon", Sun.isDaylight(noon, st.lat, st.lon));
        check("dark at midnight", !Sun.isDaylight(new Date(Date.UTC(2026, 8, 25, 23)), st.lat, st.lon));
        const next = Sun.nextChange(noon, st.lat, st.lon);
        check("next change after noon is sunset", next && Math.abs(utcMin(next) - 999) <= 3, next ? next.toISOString() : "null");
        Config.set("appearance.accent.dark", "#E06C75");
        Theme.rebuild();
        eq("custom accent", String(Theme.color.accent).toUpperCase(), "#E06C75");
        check("accent family follows", Theme.palette.accentDeep !== "#5C7596" && Theme.palette.accentText === "#0B0D10", Theme.palette.accentDeep + " " + Theme.palette.accentText);
        Config.reset("appearance.accent.dark");
        Config.set("appearance.mode", "light");
        eq("fixed light mode", ThemeMode.variant, "light");
        Config.set("appearance.mode", "dark");
        eq("fixed dark mode", ThemeMode.variant, "dark");
        Config.reset("appearance.mode");
    }

    function testConfig() {
        eq("config starts at defaults", Config.get("bar.height"), 38);
        eq("config starts unmodified", Config.modifiedKeys(""), []);

        eq("set valid", Config.set("bar.height", 44), "");
        check("set marks modified", Config.isModified("bar.height"));
        eq("file is sparse", readConfigFile(), { version: Config.formatVersion, values: { bar: { height: 44 } } });

        check("set invalid type errors", Config.set("bar.height", "tall") !== "");
        check("set unknown key errors", Config.set("bar.nope", 1) !== "");
        eq("invalid set leaves value", Config.get("bar.height"), 44);

        eq("set to default removes override", Config.set("bar.height", 38), "");
        check("…and is no longer modified", !Config.isModified("bar.height"));
        eq("…and file is empty", readConfigFile().values, {});

        Config.set("bar.height", 50);
        Config.set("bar.spacing", 10);
        Config.set("appearance.radiusScale", 1.5);
        Config.resetSection("bar");
        eq("resetSection clears only that section", Config.modifiedKeys(""), ["appearance.radiusScale"]);
        Config.reset("appearance.radiusScale");
        eq("reset single key", Config.modifiedKeys(""), []);

        Config.set("appearance.accent.dark", "#112233");
        eq("nullable set", Config.get("appearance.accent.dark"), "#112233");
        Config.set("appearance.accent.dark", null);
        check("nullable back to null removes override", !Config.isModified("appearance.accent.dark"));

        Config.set("bar.widgets", { left: [{ id: "clock" }], center: [], right: [] });
        eq("widget layout replaced, not merged", Config.get("bar.widgets"), { left: [{ id: "clock" }], center: [], right: [] });
        Config.reset("bar.widgets");

        // Preset layer
        presetWriter.path = Paths.userPresetsDir + "/test-compact.json";
        presetWriter.write(JSON.stringify({ name: "Compact", values: { bar: { height: 30 } } }));
        presetWriter.waitForJob();
        eq("setPreset", Config.setPreset("test-compact"), "");
        eq("preset changes base value", Config.get("bar.height"), 30);
        check("preset value is not a user modification", !Config.isModified("bar.height") && Config.isFromPreset("bar.height"));
        Config.set("bar.height", 30);
        check("setting the preset value stays sparse", !Config.isModified("bar.height"));
        Config.set("bar.height", 38);
        check("setting the schema default over a preset is an override", Config.isModified("bar.height"));
        Config.setPreset("default");
        Config.resetAll();
        eq("resetAll", Config.modifiedKeys(""), []);
        eq("back to schema default", Config.get("bar.height"), 38);
    }

    function testTheme() {
        Theme.rebuild();
        eq("theme chain", Theme.chainIds, ["_base", "bifrost-graphite"]);
        eq("theme has no issues", Theme.issues, []);
        eq("palette colour", Theme.color.text, "#E6EAF0");
        check("alpha colours are #AARRGGBB", /^#[0-9a-fA-F]{8}$/.test(Theme.color.hairline), Theme.color.hairline);
        check("material fill resolved", /^#[0-9a-fA-F]{8}$/.test(Theme.materials.bar.fill), Theme.materials.bar.fill);
        eq("material references radius token", Theme.materials.panel.radius, Theme.radius.xl);
        eq("easing curve", Theme.motion.curve.standard.length, 6);
        eq("prism stops", Theme.prism.stops.length, 3);
        eq("selected state uses prism", Theme.states.selected.fill, "prism");
        for (const group of ["typography", "icon", "control", "materials", "states", "prism", "motion"])
            check("Theme exposes " + group, Theme[group] && Object.keys(Theme[group]).length > 0);
        eq("typography role resolves family", Theme.typography.body.family, "Geist");
        eq("control tokens resolve refs", Theme.control.radius, Theme.radius.md);
        check("material has glass params", ["depth", "density", "sheen", "edgeTopBias", "grain", "highlight"].every(k => typeof Theme.materials.panel[k] === "number"));

        Config.set("appearance.foreground.dark", "#ABCDEF");
        Theme.rebuild();
        eq("custom foreground reaches text and icons", [Theme.color.text, Theme.color.icon, Theme.color.textMuted], ["#ABCDEF","#ABCDEF","#ABCDEF"]);
        Config.set("appearance.foreground.light", "#123456");
        Theme.rebuild();
        eq("light foreground does not override dark mode", Theme.color.text, "#ABCDEF");
        Config.reset("appearance.foreground.dark");
        Config.reset("appearance.foreground.light");
        Theme.rebuild();
        const normal = Theme.motion.duration.normal;
        Config.set("appearance.motion.speed", 2);
        Theme.rebuild();
        eq("motion speed scales durations", Theme.motion.duration.normal, normal / 2);
        Config.set("appearance.motion.enabled", false);
        Theme.rebuild();
        eq("motion disabled zeroes durations", Theme.motion.duration.slow, 0);
        Config.set("appearance.radiusScale", 0);
        Theme.rebuild();
        check("radius scale 0 keeps 'full'", Theme.radius.lg === 0 && Theme.radius.full === 9999, Theme.radius);
        Config.set("appearance.prism.intensity", 0);
        Theme.rebuild();
        eq("prism intensity 0 falls back to solid", Theme.states.selected.fill, "solid");
        Config.set("materials.transparency", 25);
        Theme.rebuild();
        check("one transparency reaches every surface", ["bar", "dock", "panel", "popover", "osd", "launcher", "controlCenter", "notifications", "settings", "settingsGroups"].every(k => Math.abs(Theme.materials[k].opacity - 0.75) < 1e-9 && Theme.materials[k].transparency === 25));
        Config.set("materials.transparency", 0);
        Theme.rebuild();
        check("transparency 0 % makes the glass solid", Theme.materials.bar.opacity === 1 && Theme.materials.bar.fill.substring(1, 3).toLowerCase() === "ff", Theme.materials.bar.fill);
        Config.reset("materials.transparency");
        Theme.rebuild();
        check("standard transparency keeps the theme glass per surface", Theme.materials.dock.opacity > 0.4 && Theme.materials.dock.opacity < 1 && Theme.materials.popover.opacity !== Theme.materials.dock.opacity && Theme.materials.lock.opacity < 1);
        Config.set("materials.tint.dark", "#112233");
        Config.set("materials.tint.light", "#DDEEFF");
        Config.set("materials.border", false);
        Theme.rebuild();
        check("tint and border reach every surface", Theme.materials.osd.tint === "#112233" && Theme.materials.bar.borderWidth === 0 && Theme.materials.settings.borderWidth === 0);
        Config.set("materials.transparency", 100);
        Theme.rebuild();
        check("100 % transparency is fully clear", ["bar", "dock", "popover", "launcher", "settings"].every(k => { const m = Theme.materials[k]; return m.opacity === 0 && m.density === 0 && m.depth === 0 && m.highlight === 0 && m.sheen === 0 && m.bevelStrength === 0 && m.elevation.opacity === 0; }));
        Config.reset("materials.transparency");
        Theme.rebuild();
        check("standard transparency keeps the glass body", Theme.materials.dock.density > 0 && Theme.materials.dock.elevation.opacity > 0);
        Config.set("materials.blur", 60);
        Theme.rebuild();
        check("one blur amount for every surface", Theme.materials.launcher.blur === 60 && Theme.materials.bar.blur === 60 && Theme.materials.tooltip.blur === 0);
        check("blur mask: layers masked, window surfaces none", Theme.materials.launcher.blurMask === Theme.glass.blurMaskShadowed && Theme.materials.settings.blurMask === 0 && Theme.materials.settingsGroups.blurMask === 0);
        Config.set("materials.blur", 0);
        Theme.rebuild();
        check("blur 0 turns blur off everywhere", Theme.materials.launcher.blur === 0 && Theme.materials.launcher.blurMask === 0);
        Config.resetSection("materials");
        Config.set("appearance.accent.dark", "#FF8800");
        Config.set("materials.tint.dark", "#112233");
        Config.set("materials.tint.light", "#DDEEFF");
        Theme.rebuild();
        eq("accent override", Theme.color.accent, "#FF8800");
        Config.set("appearance.mode", "light");
        Theme.rebuild();
        eq("light variant", Theme.palette.base, "#E8EBF0");
        check("dark accent does not change light mode", Theme.color.accent !== "#FF8800", Theme.color.accent);
        eq("light mode uses its own tint", Theme.materials.bar.tint, "#DDEEFF");
        Config.set("appearance.accent.light", "#00AA55");
        Theme.rebuild();
        eq("light accent", Theme.color.accent, "#00AA55");
        eq("dark accent kept", Config.get("appearance.accent.dark"), "#FF8800");
        Config.resetSection("materials");
        Config.set("appearance.theme", "does-not-exist");
        Theme.rebuild();
        check("unknown theme falls back with issue", Theme.chainIds[1] === "bifrost-graphite" && Theme.issues.length > 0, Theme.issues);
        Config.resetAll();
        Theme.rebuild();
        eq("theme back to defaults", Theme.issues, []);
    }

    // Every shared component must load (catches type/import errors early).
    function testComponents() {
        const files = ["Glass/GlassSurface", "State/StateFill", "State/StateLayer", "Text/BText", "Icons/BIcon",
            "Motion/BNumberAnimation", "Motion/BColorAnimation", "Controls/BButton", "Controls/BIconButton",
            "Controls/BToggle", "Controls/BSlider", "Controls/BSegmented", "Controls/BListRow",
            "Controls/BTextField", "Controls/BChip", "Controls/BDivider"];
        for (const f of files) {
            const c = Qt.createComponent(Qt.resolvedUrl("Components/" + f + ".qml"));
            check("component loads: " + f, c.status === Component.Ready, c.errorString());
            if (c.status === Component.Ready) {
                const o = c.createObject(test);
                check("component instantiates: " + f, o !== null);
                if (o)
                    o.destroy();
            }
        }
    }

    // Each Settings editor bound to a real key must read and write through Config.
    function testGroupedSettings() {
        Config.set("materials.transparency", 40);
        Theme.rebuild();
        eq("groups use the one glass", Theme.materials.settingsGroups.transparency, 40);
        eq("internal groups do not apply a layer blur mask", Theme.materials.settingsGroups.blurMask, 0);
        Config.reset("materials.transparency");
        Theme.rebuild();
    }

    function testEditors() {
        const cases = [
            ["BoolEditor", "materials.border", false],
            ["NumberEditor", "materials.blur", 40],
            ["NumberEditor", "bar.height", 44],
            ["NumberEditor", "materials.transparency", 30],
            ["ThemeModeEditor", "appearance.mode", "light"],
            ["SegmentedEditor", "keybinds.workspaceStyle", "moveFollow"],
            ["EnumEditor", "notifications.position", "bottom-right"],
            ["ColorEditor", "appearance.accent.dark", "#8899AA"],
            ["FontEditor", "appearance.font.ui", "Geist Mono"],
            ["TextEditor", "appearance.theme", "bifrost-graphite"],
            ["ThemeEditor", "appearance.theme", "bifrost-graphite"],
            ["WeatherLocationEditor", "clock.weather.location", {name:"Stockholm",lat:59.33,lon:18.07,zone:"Europe/Stockholm"}],
            ["IconThemeEditor", "appearance.icons.theme", "YAMIS"],
            ["ListEditor", "bar.screens", ["DP-2"]],
            ["ScreenListEditor", "bar.screens", ["DP-2"]],
            ["WidgetLayoutEditor", "bar.widgets", { left: [{ id: "clock" }], center: [], right: [] }],
            ["WallpaperEditor", "wallpaper.path", "/tmp/example.jpg"]
        ];
        for (const [name, key, value] of cases) {
            const c = Qt.createComponent(Qt.resolvedUrl("Settings/Editors/" + name + ".qml"));
            if (c.status !== Component.Ready) {
                check("editor loads: " + name, false, c.errorString());
                continue;
            }
            const e = c.createObject(test, { key: key });
            check("editor reads config: " + name, L.equals(e.value, Config.get(key)), { editor: e.value, config: Config.get(key) });
            e.set(value);
            eq("editor writes config: " + name + " → " + key, Config.get(key), value);
            Config.reset(key);
            e.destroy();
        }
        check("setting row picks editor", (() => {
            const c = Qt.createComponent(Qt.resolvedUrl("Settings/SettingRow.qml"));
            const r = c.status === Component.Ready ? c.createObject(test, { key: "bar.widgets" }) : null;
            const ok = r !== null && r.editorName === "WidgetLayoutEditor";
            if (r)
                r.destroy();
            return ok;
        })());
        for (const name of ["SettingsRows", "SettingsGroupSurface", "SettingsDivider", "Card", "SectionPage", "NetworkPage", "ThemeBrowserPage", "InputPage", "InputDevicePage", "InputControl", "InputGestures", "KeybindsPage", "KeybindRow", "KeybindGroupCard", "KeyChips", "KeyCaptureField"]) {
            const component = Qt.createComponent(Qt.resolvedUrl("Settings/" + name + ".qml"));
            check("settings page compiles: " + name, component.status === Component.Ready, component.errorString());
        }
        check("input keyboard subpage resolves", SettingsNav.pageInfo("input/keyboard").page === "InputPage");
        const gs = Qt.createComponent(Qt.resolvedUrl("Greeter/GreeterSurface.qml"));
        check("greeter surface compiles", gs.status === Component.Ready, gs.errorString());
        const sessions = GreeterLogic.parseSessions("@@/usr/share/wayland-sessions/hyprland.desktop\n[Desktop Entry]\nName=Hyprland\nExec=/usr/bin/start-hyprland\nDesktopNames=Hyprland\n[Desktop Action x]\nName=Other\n@@/s/hidden.desktop\n[Desktop Entry]\nName=Hidden\nExec=x\nNoDisplay=true\n@@/s/uwsm.desktop\n[Desktop Entry]\nName=A uwsm\nExec=uwsm start -e -D Hyprland hyprland.desktop\n");
        eq("greeter: sessions from desktop files", sessions.map(s => [s.id, s.name]), [["uwsm", "A uwsm"], ["hyprland", "Hyprland"]]);
        eq("greeter: session command and env", [GreeterLogic.commandOf(sessions[0].exec), GreeterLogic.sessionEnv(sessions[1])], [["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"], ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=hyprland", "XDG_CURRENT_DESKTOP=Hyprland"]]);
        eq("greeter: quoted exec, field codes dropped", GreeterLogic.commandOf("sh -c 'exec niri --session' %U"), ["sh", "-c", "exec niri --session"]);
        eq("greeter: people who can log in", GreeterLogic.parseUsers("root:x:0:0::/root:/bin/bash\nada:x:1000:1000:Ada Lovelace,,,:/home/ada:/usr/bin/zsh\nsvc:x:1001:1001::/:/usr/bin/nologin\nnobody:x:65534:65534::/:/bin/false").map(u => [u.name, u.realName]), [["ada", "Ada Lovelace"]]);
        eq("greeter: initials", [GreeterLogic.initials({ name: "ada", realName: "Ada Lovelace" }), GreeterLogic.initials({ name: "gast" }), GreeterLogic.initials(null)], ["AL", "G", "?"]);
        check("config: transient layer is not written", (() => {
            const before = Config.get("appearance.font.scale");
            Config.setTransient("appearance.font.scale", 1.3);
            const on = Config.get("appearance.font.scale") === 1.3 && !Config.isModified("appearance.font.scale");
            Config.setTransient("appearance.font.scale", undefined);
            return on && Config.get("appearance.font.scale") === before && Config.setTransient("appearance.font.scale", "big") !== "";
        })());
        check("shortcuts subpage resolves", SettingsNav.pageInfo("keybinds/shortcuts").page === "KeybindsPage");
        const ev = (key, mods, code) => ({ key: key, modifiers: mods || 0, nativeScanCode: code || 0 });
        eq("keys: event → Hyprland names", [
            KeyNames.fromEvent(ev(Qt.Key_Q, Qt.MetaModifier | Qt.ShiftModifier, 24)),
            KeyNames.fromEvent(ev(Qt.Key_Exclam, Qt.MetaModifier | Qt.ShiftModifier, 10)),
            KeyNames.fromEvent(ev(Qt.Key_Space, Qt.MetaModifier, 65)),
            KeyNames.fromEvent(ev(Qt.Key_Left, Qt.ControlModifier | Qt.AltModifier, 113)),
            KeyNames.fromEvent(ev(Qt.Key_F5, 0, 71)),
            KeyNames.fromEvent(ev(Qt.Key_VolumeUp, 0, 123)),
            KeyNames.fromEvent(ev(Qt.Key_Semicolon, Qt.MetaModifier | Qt.ShiftModifier, 59)),
            KeyNames.fromEvent(ev(Qt.Key_Super_L, Qt.MetaModifier, 133))
        ], ["SUPER + SHIFT + Q", "SUPER + SHIFT + code:10", "SUPER + space", "CTRL + ALT + left", "F5", "XF86AudioRaiseVolume", "SUPER + SHIFT + code:59", ""]);
        eq("keys: shown as keycaps", KeyNames.parts("SUPER + SHIFT + code:10").map(p => KeyNames.label(p, t => t)), ["Super", "Shift", "1"]);
        eq("keys: same combination in any order", KeyNames.id("shift + super + code:12"), KeyNames.id("SUPER + SHIFT + 3"));
        const inputDef = Schema.def("input.devices");
        check("input rejects unrelated per-device options", !L.coerce(inputDef,{mouse:{kind:"mouse",values:{kb_layout:"us"}}}).ok);
        check("input preserves inherited empty acceleration", L.coerce(inputDef,{mouse:{kind:"mouse",values:{accel_profile:"flat"},original:{accel_profile:""}}}).ok);
        check("input capabilities hide unverified features", !InputDevices.supported({kind:"trackpad",values:{},capabilities:{}}, {key:"tap_to_click",kinds:["trackpad"],capability:"tap"}));
        const inputSurface = Qt.createQmlObject("import QtQuick; Item { width: 800; height: 600; visible: false }", test);
        for (const kind of ["keyboard","mouse","trackpad"]) {
            const c = Qt.createComponent(Qt.resolvedUrl("Settings/InputDevicePage.qml"));
            const page = c.createObject(inputSurface,{kind:kind,visible:false});
            check("input page supports no-device state: "+kind,page !== null && page.device === null);
            page.destroy();
        }
        inputSurface.destroy();
        eq("schema option labels", Schema.optionLabel("appearance.mode", "dark"), "Dark");
        eq("schema group labels", Schema.groupLabel("bar", "behavior"), "Behaviour");
        check("section support", Schema.isSectionSupported("appearance") && Schema.isSectionSupported("hyprland") === (Compositor.kind === "hyprland"));
        eq("nav opens key's section", (SettingsNav.open("bar.height"), SettingsNav.page), "bar");
        eq("nav highlights key", SettingsNav.highlightKey, "bar.height");
    }

    property var layoutCases: []

    function prepareRowLayoutTests() {
        const c = Qt.createComponent(Qt.resolvedUrl("Settings/SettingRow.qml"));
        function scaleText(item, scale) {
            if (item.font && item.font.pixelSize > 0) item.font.pixelSize *= scale;
            for (const child of item.children || []) scaleText(child, scale);
        }
        for (const scale of [1, 1.5])
        for (const width of [320, 520, 800, 1400])
            for (const key of ["appearance.mode", "appearance.accent.dark", "materials.blur", "materials.border", "notifications.position", "keybinds.workspaceStyle"])
            {
                const row = c.createObject(test, { key: key, width: width,
                    note: "Lång svensk beskrivning med flera ord ochLongEnglishTextWithoutSpacesThatMustWrapCorrectly ".repeat(3) });
                scaleText(row, scale);
                layoutCases.push(row);
            }
        rowLayoutCheck.start();
    }

    Timer {
        id: rowLayoutCheck
        interval: 200
        onTriggered: {
            for (const row of test.layoutCases) {
                const texts = row.children.find(c => c.objectName === "settingTexts");
                const control = row.children.find(c => c.objectName === "settingControl");
                const separated = texts.x + texts.width <= control.x || texts.y + texts.implicitHeight <= control.y;
                test.check("settings text/control separation " + row.key + " @ " + row.width,
                    separated && texts.width > 0 && control.x >= 0 && control.x + control.width <= row.width
                    && Math.max(texts.y + texts.implicitHeight, control.y + control.height) <= row.implicitHeight);
                row.destroy();
            }
            test.layoutCases = [];
        }
    }

    function testBar() {
        for (const w of ["ScreenshotWidget", "LauncherWidget", "WorkspacesWidget", "ActiveWindowWidget", "ClockWidget", "BatteryWidget", "MediaWidget", "SystemStatsWidget", "GpuWidget", "TrayWidget", "SettingsWidget", "SpacerWidget", "ControlCenterWidget", "StatusWidget", "DisplayWidget", "NotificationsWidget", "PowerWidget"]) {
            const c = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/Widgets/" + w + ".qml"));
            check("bar widget loads: " + w, c.status === Component.Ready, c.errorString());
            if (c.status === Component.Ready) {
                const o = c.createObject(test, { entry: { id: "x" } });
                check("bar widget instantiates: " + w, o !== null && typeof o.shown === "boolean");
                if (o)
                    o.destroy();
            }
        }
        const reg = reader.read(Paths.schemaDir + "/widgets.json");
        check("widget registry lists default widgets", reg.ok && Object.values(Config.get("bar.widgets")).every(zone => zone.every(e => reg.data.widgets.some(w => w.id === e.id))));
        const host = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/WidgetHost.qml"));
        check("widget host knows every implemented widget", host.status === Component.Ready && (() => {
            const h = host.createObject(test);
            const ok = reg.data.widgets.filter(w => !w.since).every(w => h.components[w.id] !== undefined);
            h.destroy();
            return ok;
        })());
        for (const m of ["Modules/Bar/Widgets/ClockMenu", "Shared/MonthCalendar", "Shared/DayPanel"]) {
            const c = Qt.createComponent(Qt.resolvedUrl(m + ".qml"));
            check("clock menu part compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        // Reminders: made, checked off and cleared in the clock menu; kept in Store.
        const keptReminders = Store.get("reminders");
        Store.set("reminders", []);
        Reminders.add("  Köp mjölk  ");
        Reminders.add("   ");
        Reminders.add("Ring tandläkaren");
        eq("reminders: added, trimmed, blank ignored", Reminders.items.map(r => [r.text, r.done]), [["Köp mjölk", false], ["Ring tandläkaren", false]]);
        Reminders.toggle(Reminders.items[0].id);
        eq("reminders: checked off and stored", [Reminders.doneCount, Store.get("reminders")[0].done], [1, true]);
        Reminders.clearDone();
        eq("reminders: clear done keeps the rest", Reminders.items.map(r => r.text), ["Ring tandläkaren"]);
        Reminders.remove(Reminders.items[0].id);
        eq("reminders: removed", Reminders.items.length, 0);
        Store.set("reminders", keptReminders);
        for (const m of ["Modules/Bar/Widgets/WorkspacePreview", "Compat/WindowCapture", "Modules/WindowTransitions/WindowTransitions", "Modules/ControlCenter/ControlCenterContent", "Modules/ControlCenter/ControlCenter", "Modules/Dock/DockPanelHost", "Modules/Dock/Dock", "Modules/Bar/Widgets/ControlCenterWidget", "Modules/Launcher/LauncherContent", "Modules/Launcher/Launcher", "Modules/Bar/Widgets/LauncherWidget", "Modules/Bar/PanelMenu", "Modules/Notifications/NotificationCenterContent", "Modules/Notifications/NotificationCenter", "Modules/Bar/Widgets/NotificationsWidget", "Shared/AudioDevices", "Shared/WifiNetworks"]) {
            const c = Qt.createComponent(Qt.resolvedUrl(m + ".qml"));
            check("workspace preview part compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        // Workspace map tiles are updated in place (delegates, and their live
        // pictures, survive geometry polls).
        (() => {
            const lm = Qt.createQmlObject("import QtQuick; ListModel {}", test);
            const t = (id, x, y) => ({ win: { id: id, workspaceId: 1 }, x: x, y: y, width: 10, height: 10 });
            WorkspaceMap.sync(lm, [t("a", 0, 0), t("b", 20, 0)]);
            const first = lm.get(0);
            WorkspaceMap.sync(lm, [t("a", 5, 0), t("b", 20, 0)]);
            const moved = [lm.count, lm.get(0).winId, lm.get(0).tx, lm.get(0) === first];
            WorkspaceMap.sync(lm, [t("b", 20, 0), t("c", 40, 0)]);
            const rows = [];
            for (let i = 0; i < lm.count; i++)
                rows.push([lm.get(i).winId, lm.get(i).order]);
            eq("workspace map: tiles kept by window id", [moved.slice(0, 3), rows], [[2, "a", 5], [["b", 0], ["c", 1]]]);
            lm.destroy();
        })();
        // Workspace map: monitor in physical px (scale 2), windows in logical px;
        // off-screen parts clipped, floating above tiled.
        const wm = WorkspaceMap.layout({ x: 100, y: 0, width: 2000, height: 1000, scale: 2 }, [
            { id: "f", x: 600, y: 250, width: 200, height: 100, floating: true },
            { id: "t", x: 100, y: 0, width: 500, height: 500, floating: false },
            { id: "off", x: 1200, y: 0, width: 100, height: 100 },
            { id: "half", x: 1050, y: 400, width: 200, height: 200 }], 400);
        eq("workspace map: size, clipping and order", [wm.width, wm.height, wm.windows.map(w => [w.win.id, w.x, w.y, w.width, w.height])],
            [400, 200, [["t", 0, 0, 200, 200], ["half", 380, 160, 20, 40], ["f", 200, 100, 80, 40]]]);
        const wx = Weather.parse('{"current":{"temperature_2m":12.2,"apparent_temperature":11.3,"weather_code":3,"is_day":0,"wind_speed_10m":4.3,"relative_humidity_2m":81},"daily":{"time":["2026-09-25","2026-09-26"],"temperature_2m_max":[13.6,14.9],"temperature_2m_min":[11.3,12.0],"weather_code":[51,1]}}');
        check("weather: open-meteo answer parsed", wx && wx.current.temperature === 12.2 && !wx.current.isDay && wx.daily.length === 2 && wx.daily[1].code === 1, JSON.stringify(wx));
        check("weather: unusable answer rejected", Weather.parse("{}") === null && Weather.parse("<html>") === null);
        eq("weather: icons by WMO code", [Weather.icon(0, true), Weather.icon(0, false), Weather.icon(2, true), Weather.icon(61, true), Weather.icon(73, true), Weather.icon(45, true), Weather.icon(95, true)], ["sun", "moon", "cloud-sun", "cloud-rain", "cloud-snow", "cloud-fog", "cloud-lightning"]);
        eq("iso week", Time.isoWeek(new Date(2026, 8, 24)), 39);
        eq("iso week at year start", Time.isoWeek(new Date(2027, 0, 1)), 53);
        SystemStats.sample();
        SystemStats.sample();
        check("cpu in range", SystemStats.cpu >= 0 && SystemStats.cpu <= 1, SystemStats.cpu);
        check("memory read", SystemStats.memTotalKb > 0 && SystemStats.mem > 0 && SystemStats.mem < 1, SystemStats.mem);
        check("compositor has relative workspace nav", typeof Compositor.focusRelativeWorkspace === "function");
        check("focus grab capability declared", typeof Compositor.capabilities.focusGrab === "boolean");
    }

    // Bar menus: they compile, the shape joining a menu to the bar glass is
    // right (centred, flush, wider than an island, bar at the bottom), the
    // recent-files parser and the force-quit gate.
    function testBarMenus() {
        const stable = Qt.createQmlObject(`import QtQuick; Item {
            id: fixture
            property int created: 0
            property alias rows: rows
            property alias repeater: repeats
            ListModel { id: rows }
            Repeater {
                id: repeats
                model: rows
                delegate: Item { required property string entryKey; Component.onCompleted: fixture.created++ }
            }
        }`, test);
        DockModel.syncKeys(stable.rows,["a","b"]);
        const retained = stable.repeater.itemAt(0);
        for (let poll=0;poll<10;poll++) DockModel.syncKeys(stable.rows,["a","b"]);
        check("dock polls preserve hover delegates", stable.created === 2 && stable.repeater.itemAt(0) === retained);
        DockModel.syncKeys(stable.rows,["b","a","c"]);
        check("dock reorder moves existing delegates", stable.created === 3 && stable.repeater.itemAt(1) === retained);
        DockModel.syncKeys(stable.rows,["a"]);
        check("dock removes only closed entries", stable.rows.count === 1 && stable.repeater.itemAt(0) === retained);
        stable.destroy();

        // The preview is a plain item on its owning dock, never a native popup.
        const previewSurface = Qt.createQmlObject("import QtQuick; Item {}", test);
        const previewOwner = Qt.createQmlObject(`import QtQuick; Item {
            property bool previewEnabled: true
            property bool hovered: true
            property string edge: "bottom"
            property string name: "Test app"
            property var model: ({windows:[]})
            x: 400; y: 500; width: 48; height: 48
        }`, test);
        const previewHost = Qt.createComponent(Qt.resolvedUrl("Modules/Dock/DockPreview.qml")).createObject(previewSurface, {screenWidth:800, screenHeight:600});
        previewHost.show(previewOwner);
        check("dock preview remains on the dock surface", previewHost.open && previewHost.parent === previewSurface && previewHost.owner === previewOwner);
        previewOwner.model = {windows:[]};
        check("dock preview survives refreshed window data", previewHost.open && previewHost.owner === previewOwner);
        previewOwner.previewEnabled = false;
        check("dock preview closes when its app stops running", !previewHost.open && previewHost.owner === null);
        previewHost.show(previewOwner);
        check("dock preview cannot open for a closed app", !previewHost.open);
        previewHost.destroy();
        previewOwner.destroy();
        previewSurface.destroy();

        const testWins=Array.from({length:17},(_,i)=>({id:String(i),width:i%2 ? 300 : 1600,height:i%2 ? 1200 : 900}));
        for(const dimensions of [[1200,600],[600,1000],[4000,800]]) {
            const boxes=OverviewLayout.layout(testWins,dimensions[0],dimensions[1],16,32);
            check("overview stays inside monitor "+dimensions,boxes.every(b=>b.x>=0 && b.y>=0 && b.x+b.width<=dimensions[0]+0.01 && b.y+b.height+32<=dimensions[1]+0.01));
            check("overview preserves proportions "+dimensions,boxes.every((b,i)=>Math.abs(b.width/b.height-testWins[i].width/testWins[i].height)<0.001));
            check("overview tiles never overlap "+dimensions,boxes.every((a,i)=>boxes.every((b,j)=>i===j || a.x+a.width<=b.x || b.x+b.width<=a.x || a.y+a.height+32<=b.y || b.y+b.height+32<=a.y)));
        }
        // Few windows stay small (capped) and centred; an ultrawide area lays them out in one row.
        const few=[{id:"a",width:2560,height:1440},{id:"b",width:1280,height:1400},{id:"c",width:5120,height:1400}];
        const capped=OverviewLayout.layout(few,5000,1200,44,34,840,350);
        check("overview caps picture size", capped.every(b=>b.height<=350.01 && b.width<=840.01), capped);
        check("overview uses one row on an ultrawide screen", capped.every(b=>Math.abs(b.y+b.height/2-capped[0].y-capped[0].height/2)<0.01));
        const left=Math.min(...capped.map(b=>b.x)), right=Math.max(...capped.map(b=>b.x+b.width));
        check("overview centres the grid", Math.abs(left-(5000-right))<0.01 && Math.abs(capped[0].y+capped[0].height/2-(1200-34)/2)<1);
        const one=OverviewLayout.layout([few[0]],5000,1200,44,34,840,350);
        check("overview keeps a single window small", one[0].height<=350.01 && one[0].width<5000/4);
        eq("overview short title drops the app suffix", [OverviewLayout.shortTitle("Inbox - Mail — Vivaldi","Vivaldi"), OverviewLayout.shortTitle("notes.txt - gedit","Text Editor"), OverviewLayout.shortTitle("","Kitty")], ["Inbox - Mail", "notes.txt - gedit", "Kitty"]);
        const dockApps = [{key:"a"},{key:"b"}];
        eq("dock ranks running apps without pins", DockModel.ordered(dockApps,["b","a"]).map(e=>e.key),["b","a"]);
        eq("dock drop moves forward",DockModel.dropOrder(["a","b","c"],"a","c"),["b","a","c"]);
        eq("dock drop moves to end",DockModel.dropOrder(["a","b","c"],"a",""),["b","c","a"]);
        eq("dock remembers closed apps",DockModel.rememberOrder(["closed","a","b"],["b","a"]),["b","a","closed"]);
        eq("dock launcher inserts at chosen position", DockModel.withLauncher(dockApps,true,1).map(x=>x.key), ["a","bifrost-launcher","b"]);
        eq("dock launcher clamps position", DockModel.withLauncher(dockApps,true,99).map(x=>x.key), ["a","b","bifrost-launcher"]);
        eq("dock launcher preserves app list", dockApps.length, 2);
        check("weather rejects invalid custom coordinates", !Weather.validLocation({lat:100,lon:0}) && !Weather.validLocation({lat:"59",lon:18}) && Weather.validLocation({lat:59,lon:18}));

        const inset = {left:12,right:12,top:38,bottom:12};
        for (const edge of ["top","bottom","left","right","free"]) {
            const r = DockGeometry.rect(edge,1920,1080,600,60,inset,0,0.3,0.7);
            check("dock fits screen at " + edge, r.x >= 12 && r.y >= 38 && r.x+r.width <= 1908 && r.y+r.height <= 1068);
            if (edge !== "free") {
                const b = edge === "top" ? {x:0,y:0,width:1920,height:38} : edge === "bottom" ? {x:0,y:1068,width:1920,height:12} : edge === "left" ? {x:0,y:0,width:12,height:1080} : {x:1908,y:0,width:12,height:1080};
                const a = GlassJoin.between(b,r,edge,12,16,true);
                eq("frame dock joins the " + edge + " border", [a.ext.x,a.ext.y,a.ext.width,a.ext.height], [r.x,r.y,r.width,r.height]);
            }
        }
        eq("dock join shrinks during bottom reveal", DockGeometry.frameExtension("bottom",{x:100,y:950,width:400,height:80},1200,1000,10).height,40);
        eq("dock join vanishes behind frame", DockGeometry.frameExtension("bottom",{x:100,y:990,width:400,height:80},1200,1000,10),null);
        eq("dock join shrinks during left reveal", DockGeometry.frameExtension("left",{x:-30,y:100,width:80,height:400},1200,1000,10).width,40);
        const freeDock = DockGeometry.rect("free",800,600,300,60,inset,0,2,-1);
        check("free dock clamps drag position", freeDock.x+freeDock.width === 788 && freeDock.y === 38);

        for (const m of ["BarWindow", "BarMenu", "MenuHost", "MenuItem", "SystemStatusPopup", "Widgets/SystemMenu", "Widgets/StatusMenu", "Widgets/TrayMenu"]) {
            const c = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/" + m + ".qml"));
            check("bar menu part compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        const topBar = Qt.createQmlObject("import QtQuick; QtObject { property bool atBottom: false; property real barHeight: 38 }", test);
        const bottomBar = Qt.createQmlObject("import QtQuick; QtObject { property bool atBottom: true; property real barHeight: 38 }", test);
        const glass = Qt.createQmlObject("import QtQuick; Item { width: 1000; height: 38; property real radius: 10; property real stripY: 0; property real stripHeight: height; property rect hole }", test);
        const island = Qt.createQmlObject("import QtQuick; Item { x: 100; width: 40; height: 38; property real radius: 10; property real stripY: 0; property real stripHeight: height; property rect hole }", test);
        const hc = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/MenuHost.qml"));
        const shape = (bar, g, x, w, h) => {
            const host = hc.createObject(test, { bar: bar, width: 1000, height: 38, hostGlass: g, shapeX: x, shapeWidth: w, shapeHeight: h });
            const a = host.attachmentFor(g);
            host.destroy();
            return a ? { ext: [a.ext.x, a.ext.y, a.ext.width, a.ext.height], bridge: [a.bridge.x, a.bridge.y, a.bridge.width, a.bridge.height], radii: a.radii, extRadii: a.extRadii, fillets: a.fillets } : null;
        };
        const R = Theme.radius.lg;
        eq("menu shape: centred under the bar", shape(topBar, glass, 400, 200, 100), { ext: [400, 38, 200, 100], bridge: [400, 19, 200, 38], radii: [10, 10, 10, 10], extRadii: [R, 0, R, 0], fillets: [[400, 38, -R, R], [600, 38, R, R]] });
        eq("menu shape: flush with the bar edge", shape(topBar, glass, 0, 200, 100), { ext: [0, 38, 200, 100], bridge: [0, 19, 200, 38], radii: [10, 10, 0, 10], extRadii: [R, 0, R, 0], fillets: [[200, 38, R, R]] });
        eq("menu shape: wider than its island", shape(topBar, island, 100, 280, 100), { ext: [0, 38, 280, 100], bridge: [0, 19, 40, 38], radii: [0, 10, 0, 10], extRadii: [R, R, R, 0], fillets: [[40, 38, R, -R]] });
        eq("menu shape: bar at the bottom", shape(bottomBar, glass, 400, 200, 100), { ext: [400, -100, 200, 100], bridge: [400, -19, 200, 38], radii: [10, 10, 10, 10], extRadii: [0, R, 0, R], fillets: [[400, 0, -R, -R], [600, 0, R, -R]] });
        eq("menu shape: other glass untouched", shape(topBar, glass, 400, 200, 0), null);
        const frameTop = Qt.createQmlObject("import QtQuick; Item { x: -6; width: 1000; height: 800; property real radius: 10; property real stripY: 0; property real stripHeight: 38; property rect hole: Qt.rect(6, 38, 988, 756) }", test);
        const ft = shape(topBar, frameTop, 400, 200, 100);
        check("menu shape: grows from a frame's bar side, square outer corners", ft && ft.ext[1] === 38 && ft.ext[0] === 406 && ft.radii.join() === "0,0,0,0", JSON.stringify(ft));
        const frameBottom = Qt.createQmlObject("import QtQuick; Item { x: -6; width: 1000; height: 800; property real radius: 10; property real stripY: 762; property real stripHeight: 38; property rect hole: Qt.rect(6, 6, 988, 756) }", test);
        const fb = shape(bottomBar, frameBottom, 400, 200, 100);
        check("menu shape: bottom frame grows upward from its bar side", fb && fb.ext[1] === 662, JSON.stringify(fb));
        const xml = '<xbel><bookmark href="file:///tmp/a%20b.txt" modified="2026-09-02T10:00:00Z"><info><mime:mime-type type="text/plain"/></info></bookmark>'
            + '<bookmark href="https://example.org/" modified="2026-09-09T00:00:00Z"></bookmark>'
            + '<bookmark href="file:///tmp/dir" modified="2026-09-05T00:00:00Z"><info><mime:mime-type type="inode/directory"/></info></bookmark></xbel>';
        eq("recent files: newest first, local files only, decoded", RecentFiles.parse(xml).map(i => [i.path, i.name, i.mime]), [["/tmp/dir", "dir", "inode/directory"], ["/tmp/a b.txt", "a b.txt", "text/plain"]]);
        check("overlay mode forbids force quit", !Session.canForceQuit);
        for (const m of ["HoverIntent", "LeaveWatch"]) {
            const c = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/" + m + ".qml"));
            check("bar menu part compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        // Panel leave rects: a point on another bar widget inside the panel's
        // width must count as outside, or the panel blocks hover-switching.
        const lw = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/LeaveWatch.qml")).createObject(test);
        const inAny = (rs, x, y) => rs.some(r => x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height);
        const pTop = { x: 4600, y: 62, width: 480, height: 500 }, aTop = { x: 5040, y: 11, width: 36, height: 36 };
        const rTop = lw.panelRects(pTop, aTop, "top");
        check("panel leave rects: another bar widget above the panel is outside", !inAny(rTop, 4700, 25), JSON.stringify(rTop));
        check("panel leave rects: button, gap and panel are inside", inAny(rTop, 5050, 25) && inAny(rTop, 5050, 55) && inAny(rTop, 4700, 55) && inAny(rTop, 4700, 300));
        const rBottom = lw.panelRects({ x: 4600, y: 900, width: 480, height: 480 }, { x: 5040, y: 1393, width: 36, height: 36 }, "bottom");
        check("panel leave rects: bottom bar, other widget outside, gap inside", !inAny(rBottom, 4700, 1410) && inAny(rBottom, 4700, 1385));
        const rLeft = lw.panelRects({ x: 62, y: 11, width: 480, height: 500 }, { x: 11, y: 11, width: 36, height: 36 }, "left");
        check("panel leave rects: side bar, other widget along the bar outside", !inAny(rLeft, 25, 200) && inAny(rLeft, 55, 200));
        eq("panel leave rects: no anchor, panel only", lw.panelRects(pTop, null, "top").length, 1);
        lw.destroy();
        // Moving on from an open bar menu or panel switches without the hover delay.
        const hi = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/HoverIntent.qml")).createObject(test);
        const idleDelay = hi.interval;
        ShellState.controlCenterOpen = true;
        const panelDelay = hi.interval;
        ShellState.controlCenterOpen = false;
        check("hover intent: delay when nothing is open, none while a panel is open", idleDelay === Config.values.bar.menus.hoverDelayMs && panelDelay === 0, idleDelay + "/" + panelDelay);
        hi.destroy();
        // Hover opening and top padding on a menu with a stand-in host.
        const fakeHost = Qt.createQmlObject("import QtQuick; Item { property Item menuLayer: this; property var shown: null; function show(m) { shown = m } function hide(m) { if (shown === m) shown = null } }", test);
        const hoverBar = Qt.createQmlObject("import QtQuick; QtObject { property bool atBottom: false; property real barHeight: 38; property var menuHost }", test);
        hoverBar.menuHost = fakeHost;
        const anchor = Qt.createQmlObject("import QtQuick; Item { property bool hovered: false }", test);
        const bm = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/BarMenu.qml")).createObject(test, { bar: hoverBar, anchorItem: anchor });
        Qt.createQmlObject("import QtQuick; Item { width: 100; height: 50 }", bm);
        const h0 = bm.menuHeight;
        Config.set("bar.menus.contentTopPadding", 6);
        eq("menu top padding adds room above the content only", bm.menuHeight - h0, 6);
        // Side bar: the menu is turned with the bar, so along the bar it is
        // as long as its content is tall, and the extra padding faces the bar.
        const sideBar = Qt.createQmlObject("import QtQuick; QtObject { property bool atBottom: true; property bool vertical: true; property string edge: \"left\"; property real barHeight: 38; property var menuHost }", test);
        sideBar.menuHost = fakeHost;
        const sm0 = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/BarMenu.qml")).createObject(test, { bar: sideBar, anchorItem: anchor });
        sm0.contentWidth = 100;
        sm0.contentHeight = 50;
        eq("side bar menu: length along the bar is the content height", sm0.menuWidth, Math.ceil(50 + sm0.padding * 2));
        eq("side bar menu: depth is the content width plus bar-side padding", sm0.menuHeight, Math.ceil(100 + sm0.padding + sm0.topPadding));
        sm0.destroy();
        sideBar.destroy();
        const row = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/Widgets/BarRow.qml")).createObject(test, { spacing: 0 });
        for (let i = 0; i < 3; i++)
            Qt.createQmlObject("import QtQuick; Item { width: 10; height: 20 }", row);
        row.forceLayout();
        const flat = [row.implicitWidth, row.implicitHeight];
        row.vertical = true;
        row.forceLayout();
        eq("bar row stacks on a side bar", [flat, [row.implicitWidth, row.implicitHeight]], [[30, 20], [10, 60]]);
        row.destroy();
        Config.set("bar.position", "left");
        eq("metrics: side bar edge and space", [Metrics.barEdge, Metrics.barVertical, Metrics.edgeSpace("left") === Metrics.barSpace, Metrics.edgeSpace("top")], ["left", true, true, 0]);
        eq("metrics: bar width is a share of the edge", Metrics.barWidth, 1);
        Config.set("bar.width", 40);
        eq("metrics: narrower bar", Metrics.barWidth, 0.4);
        Config.set("bar.layout", "frame");
        eq("metrics: a frame always spans the edge", Metrics.barWidth, 1);
        Config.reset("bar.layout");
        Config.reset("bar.width");
        Config.set("bar.position", "top");
        Config.set("bar.menus.hoverDelayMs", 0);
        anchor.hovered = true;
        test.hoverCase = { menu: bm, anchor: anchor, host: fakeHost, bar: hoverBar };
        hoverCheck.start();
        const sm = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/Widgets/SystemMenu.qml")).createObject(test);
        check("system menu instantiates without a bar", sm !== null && sm.page === "main" && Array.isArray(sm.runningApps) && !sm.isOpen);
        if (sm) {
            sm.open();
            check("menu without a bar does not open", !sm.isOpen);
            sm.destroy();
        }
        for (const o of [topBar, bottomBar, glass, island])
            o.destroy();
    }

    // Phase 5: window modules must compile (not instantiated: they would open
    // real windows), services and pure logic are exercised directly.
    function testPhase5() {
        for (const m of ["Launcher/Launcher", "ControlCenter/ControlCenter", "ControlCenter/CCTile", "ControlCenter/CCSlider", "Dock/Dock", "Dock/DockItem", "Dock/DockPreview", "Dock/DockMenu", "Osd/Osd", "ModulesIpc"]) {
            const c = Qt.createComponent(Qt.resolvedUrl("Modules/" + m + ".qml"));
            check("module compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        const fakeApps = { a: { id: "a", name: "A" }, b: { id: "b", name: "B" }, c: { id: "c", name: "C" } };
        const wins = [{ id: "1", appId: "b" }, { id: "2", appId: "c" }, { id: "3", appId: "b" }, { id: "4", appId: "zz" }];
        const built = DockModel.build(["a", "b"], wins, true, id => fakeApps[id] || null, id => fakeApps[id] || null);
        eq("dock order: pinned, then running", built.map(e => e.key), ["a", "b", "c", "window:zz"]);
        eq("dock groups windows per app", built.map(e => e.windows.length), [0, 2, 1, 1]);
        eq("dock pinned flags", built.map(e => e.pinned), [true, true, false, false]);
        eq("dock hides running when disabled", DockModel.build(["a"], wins, false, id => fakeApps[id] || null, id => fakeApps[id] || null).length, 1);
        eq("dock move right", DockModel.moved(["a", "b", "c"], "a", 1), ["b", "a", "c"]);
        eq("dock move at edge is a no-op", DockModel.moved(["a", "b"], "b", 1), ["a", "b"]);

        check("audio service", typeof Audio.volume === "number" && typeof Audio.available === "boolean");
        check("network service", typeof NetworkStatus.label === "string");
        check("bluetooth service", typeof BluetoothStatus.label === "string");
        check("brightness service", typeof Brightness.available === "boolean");
        check("vpn service", typeof Vpn.available === "boolean");
        check("launch: unit name escaped like systemd-escape", Platform.escapeUnit("vivaldi-stable") === "vivaldi\\x2dstable" && Platform.escapeUnit("org.gnome.Nautilus") === "org.gnome.Nautilus" && Platform.escapeUnit("a b") === "a\\x20b", Platform.escapeUnit("vivaldi-stable"));
        (() => {
            const c = Platform.launchCommand(["kitty", "-e", "btop"], { appId: "kitty.desktop" }, true);
            check("launch: app in its own scope", c[0] === "systemd-run" && c.indexOf("--scope") > 0 && /^--unit=app-bifrost-kitty-[0-9a-f]+$/.test(c[c.indexOf("--") - 1]) && c.slice(c.indexOf("--") + 1).join(" ") === "kitty -e btop", JSON.stringify(c));
            check("launch: unscoped is the command itself", JSON.stringify(Platform.launchCommand(["xdg-open", "/tmp"], {}, false)) === '["xdg-open","/tmp"]');
        })();
        (() => {
            const saved = Placement.dockEntries;
            Placement.dockEntries = 3;
            const withDock = [Placement.resolve("dock", "bar"), Placement.resolve("bar", "bar"), Placement.resolve("center", "bar"), Placement.resolve("", "bar")];
            Placement.dockEntries = 0;
            const noDock = Placement.resolve("dock", "bar");
            Placement.dockEntries = saved;
            eq("placement: dock, else the fallback", [withDock, noDock], [["dock", "bar", "center", "bar"], "bar"]);
        })();
        (() => {
            const saved = Placement.dockEntries;
            Placement.dockEntries = 3;
            const fake = {};
            const before = [Placement.placeFor("launcher", "bar", "center", "TEST-1"), Placement.placeFor("launcher", "dock", "center", "TEST-1"), Placement.placeFor("launcher", "center", "center", "TEST-1")];
            Placement.registerBarHost("launcher", "TEST-1", fake);
            const withHost = Placement.placeFor("launcher", "bar", "center", "TEST-1");
            Placement.unregisterBarHost("launcher", "TEST-1", fake);
            Placement.dockEntries = 0;
            const noDock = Placement.placeFor("launcher", "dock", "center", "TEST-1");
            Placement.dockEntries = saved;
            eq("placement: top panel needs the button on that screen, dock needs a dock", [before, withHost, noDock, Placement.barHost("launcher", "TEST-1")], [["center", "dock", "center"], "bar", "center", null]);
        })();
        eq("launcher: explicit panel placement survives missing widget", Placement.resolve("bar", "center"), "bar");
        check("placement: launcher defaults to the dock", Schema.def("launcher.placement") !== null && Schema.def("launcher.placement").default === "dock");
        check("placement: control center defaults to the top panel", Schema.def("controlCenter.placement") !== null && Schema.def("controlCenter.placement").default === "bar");
        // Audio devices: kind from the node, Bluetooth card profiles.
        eq("audio: device kinds", [
            { name: "bluez_output.F4_33_B7_EF_68_05.1", isSink: true },
            { name: "alsa_output.pci-0000_07_00.1.hdmi-stereo", isSink: true },
            { name: "alsa_output.pci-0000_09_00.4.iec958-stereo", isSink: true },
            { name: "alsa_output.usb-headset.analog-stereo", isSink: true, properties: { "device.form-factor": "headset" } },
            { name: "alsa_output.pci.analog-stereo", isSink: true },
            { name: "alsa_input.pci.analog-stereo", isSink: false }
        ].map(n => Audio.kindOf(n)), ["bluetooth", "display", "digital", "headphones", "speaker", "mic"]);
        (() => {
            const cards = Audio.parseCards(JSON.stringify([
                { name: "alsa_card.pci", properties: { "device.api": "alsa" }, active_profile: "output:hdmi-stereo", profiles: {} },
                { name: "bluez_card.F4_33_B7_EF_68_05", properties: { "device.api": "bluez5", "device.description": "AirPods" }, active_profile: "a2dp-sink",
                    profiles: { "off": { available: true }, "a2dp-sink-sbc": { available: true }, "a2dp-sink": { available: true }, "headset-head-unit-cvsd": { available: true }, "headset-head-unit": { available: true } } }
            ]));
            const c = cards[0];
            const saved = Audio.btCards;
            Audio.btCards = cards;
            const found = Audio.cardOf({ name: "bluez_output.F4_33_B7_EF_68_05.1" });
            Audio.btCards = saved;
            eq("audio: bluetooth cards, two profile choices", [cards.length, c.name, Audio.profileChoices(c).map(p => p.id), Audio.activeChoice(c), found === c], [1, "AirPods", ["a2dp-sink", "headset-head-unit"], "music", true]);
        })();
        // Wi-Fi: security classes, signal icons, when a password is asked.
        eq("wifi: security", [WifiSecurityType.Open, WifiSecurityType.Owe, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae, WifiSecurityType.StaticWep, WifiSecurityType.WpaEap].map(t => NetworkStatus.securityOf({ security: t })), ["open", "open", "psk", "psk", "psk", "enterprise"]);
        eq("wifi: signal icons", [0.9, 0.5, 0.1].map(v => NetworkStatus.signalIcon(v)), ["wifi", "wifi-2", "wifi-1"]);
        eq("wifi: password only for new protected networks", [
            NetworkStatus.needsPassword({ known: false, security: WifiSecurityType.Wpa2Psk }),
            NetworkStatus.needsPassword({ known: true, security: WifiSecurityType.Wpa2Psk }),
            NetworkStatus.needsPassword({ known: false, security: WifiSecurityType.Open })
        ], [true, false, false]);
        check("vpn phase", ["off", "connecting", "on"].indexOf(Vpn.phase) !== -1, Vpn.phase);
        check("power service order", JSON.stringify(Power.order) === JSON.stringify(["power-saver", "balanced", "performance"]));
        check("media service", typeof Media.available === "boolean");
        ShellState.showOsd("volume", 0.5, false);
        check("osd state", ShellState.osdVisible && ShellState.osdKind === "volume");
        ShellState.osdVisible = false;
        ShellState.showMediaOsd("next");
        check("osd: media key feedback", ShellState.osdVisible && ShellState.osdKind === "media" && ShellState.osdAction === "next");
        ShellState.osdVisible = false;
        Config.set("osd.media", false);
        ShellState.showMediaOsd("next");
        check("osd: media feedback can be turned off", !ShellState.osdVisible);
        Config.set("osd.media", true);
        ShellState.toggleLauncher("X");
        check("launcher state", ShellState.launcherOpen && ShellState.launcherScreen === "X");
        ShellState.toggleControlCenter("X", null);
        check("opening the control center closes the launcher", ShellState.controlCenterOpen && !ShellState.launcherOpen);
        ShellState.controlCenterOpen = false;
        const ccAnchor = { item: null, bar: null };
        ShellState.openControlCenter("X", ccAnchor, true);
        check("hover opens the control center with its anchor", ShellState.controlCenterOpen && ShellState.controlCenterByHover && ShellState.controlCenterAnchor === ccAnchor);
        ShellState.controlCenterOpen = false;
    }

    // Desktop entries load asynchronously; runs once they are in.
    function testApps() {
        check("apps listed", Apps.all.length > 0, Apps.all.length);
        const windowAction = {id:"new-window",command:["browser","--new-window"]};
        const browser = {entry:{command:["browser"],actions:[{id:"new-private-window",command:["browser","--private"]},windowAction]}};
        check("app new window uses explicit action, not private window", Apps.newWindowAction(browser) === windowAction);
        check("kitty supports independent windows", Apps.supportsNewWindow({entry:{command:["kitty"],actions:[]}}));
        check("single-instance apps do not promise new windows", !Apps.supportsNewWindow({entry:{command:["chatgpt"],actions:[]}}));

        check("apps have icons", Apps.all.every(a => typeof a.icon === "string"));
        const provider = Qt.createComponent(Qt.resolvedUrl("Modules/Launcher/Providers/AppsProvider.qml")).createObject(test);
        const all = provider.search("");
        eq("empty query lists every visible app", all.length, Apps.all.length);
        const some = Apps.all[0];
        const hits = provider.search(some.name.substring(0, 3)).sort((a, b) => b.score - a.score);
        check("prefix search ranks the app first-tier", hits.length > 0 && hits[0].score >= 80, hits.slice(0, 2).map(h => h.title));
        check("short queries skip descriptions", provider.search("zq").length === 0);
        provider.destroy();

    }

    function fakeNotification(id, critical) {
        return {
            id: id,
            tracked: false,
            appName: "Test",
            appIcon: "",
            summary: "Summary " + id,
            body: "Body",
            image: "",
            urgency: critical ? 2 : 1,
            expireTimeout: -1,
            actions: [],
            dismissed: false,
            dismiss: function () {
                this.dismissed = true;
            },
            closed: {
                connect: function () {}
            }
        };
    }

    function testPhase6() {
        for (const m of ["Notifications/NotificationCard", "Notifications/NotificationPopups", "Notifications/NotificationCenter", "Lock/Lock", "Lock/LockSurface", "PowerMenu/PowerMenu", "Overview/Overview", "Bluetooth/PairingAgent", "Prompt/SystemPrompt", "Prompt/PolkitPrompt", "Idle/Idle", "GreeterSync"]) {
            const c = Qt.createComponent(Qt.resolvedUrl("Modules/" + m + ".qml"));
            check("module compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        eq("overlay mode owns no notification server", Notify.active, false);
        check("overlay mode forbids session actions", !Session.canLock && !Session.canLogout && !Session.canPower && Session.reason() !== "");

        Config.set("notifications.maxVisible", 2);
        Notify.clearAll();
        for (let i = 1; i <= 3; i++)
            Notify.receive(fakeNotification(i, false));
        eq("popups newest first, capped", Notify.popups.map(p => p.id), [3, 2]);
        eq("history keeps all", Notify.history.map(h => h.id), [3, 2, 1]);
        eq("unread counts", Notify.unread, 3);
        Notify.hidePopup(3);
        check("hiding a popup keeps history", Notify.popups.length === 1 && Notify.history.length === 3);
        const n2 = Notify.history.find(h => h.id === 2).source;
        Notify.dismiss(2);
        check("dismiss tells the sender and forgets", n2.dismissed && !Notify.history.some(h => h.id === 2));
        Notify.setDnd(true);
        Notify.receive(fakeNotification(10, false));
        Notify.receive(fakeNotification(11, true));
        check("do-not-disturb suppresses normal popups only", !Notify.popups.some(p => p.id === 10) && Notify.popups.some(p => p.id === 11));
        check("do-not-disturb still records history", Notify.history.some(h => h.id === 10));
        Notify.setDnd(false);
        Notify.markRead();
        eq("mark read", Notify.unread, 0);
        Notify.clearAll();
        eq("clear all", Notify.history.length + Notify.popups.length, 0);
        Config.reset("notifications.maxVisible");
        Config.reset("notifications.doNotDisturb");

        ShellState.togglePowerMenu("X");
        check("power menu state", ShellState.powerMenuOpen && !ShellState.launcherOpen);
        ShellState.toggleNotificationCenter("X", null);
        check("panels are exclusive", ShellState.notificationCenterOpen && !ShellState.powerMenuOpen);
        ShellState.toggleNotificationCenter("X", null);
        check("notification button closes the open panel", !ShellState.notificationCenterOpen);
        const notificationAnchor = { item: null, bar: null };
        ShellState.openNotificationCenter("X", notificationAnchor);
        check("notification hover opens with its anchor", ShellState.notificationCenterOpen && ShellState.notificationCenterAnchor === notificationAnchor);
        ShellState.openNotificationCenter("X", notificationAnchor);
        check("notification hover does not toggle an open panel", ShellState.notificationCenterOpen);
        ShellState.toggleNotificationCenter("X", notificationAnchor);
        check("click closes a hover-opened notification panel", !ShellState.notificationCenterOpen);
        ShellState.closePanels();
        check("compositor exposes exitSession", typeof Compositor.capabilities.exitSession === "boolean");
    }

    function testPhase7() {
        for (const m of ["Modules/Wallpaper/Wallpaper", "Settings/ProfilesPage", "Settings/TransferPage", "Settings/BluetoothPage", "Settings/DisplayPage", "Settings/GreeterControl", "Shared/BluetoothDevices", "Modules/Bar/Widgets/StatusMenu", "Modules/Bar/Widgets/AudioMenu", "Modules/Bar/Widgets/VpnMenu", "Modules/Bar/Widgets/NetworkMenu", "Modules/Bar/Widgets/BluetoothMenu", "Modules/Bar/Widgets/DisplayMenu", "Modules/Bar/SystemStatusPopup", "Modules/Bar/BarZone", "Settings/PageBase", "Settings/Card"]) {
            const c = Qt.createComponent(Qt.resolvedUrl(m + ".qml"));
            check("compiles: " + m, c.status === Component.Ready, c.errorString());
        }
        for (const theme of ["bifrost-graphite", "bifrost-fjord"]) {
            for (const variant of ["dark", "light"]) {
                Config.set("appearance.theme", theme);
                Config.set("appearance.mode", variant);
                Theme.rebuild();
                eq("theme " + theme + "/" + variant + " has no issues", Theme.issues, []);
                check("theme " + theme + "/" + variant + " material alphas valid", Object.values(Theme.materials).every(m => m.opacity >= 0 && m.opacity <= 1));
            }
        }
        Config.reset("appearance.theme");
        Config.reset("appearance.mode");
        Theme.rebuild();
        eq("overlay mode does not own the wallpaper", RunMode.ownsWallpaper, false);
        Store.set("selftest", { a: 1 });
        eq("store keeps sections", Store.get("selftest"), { a: 1 });
        eq("platform expands home", Platform.expandHome("~/x"), Paths.home + "/x");
    }

    function testCtl() {
        Ctl.run(["preset", "list", "--json"], (ok, out, data) => {
            test.check("bifrostctl runs from QML", ok && Array.isArray(data) && data.some(p => p.id === "compact"), out);
            test.testWatcher();
        }, test);
    }

    function testApplyState() {
        ApplyState.publish(Date.now(), JSON.parse(JSON.stringify(Config.values)));
        eq("nothing pending after publish", ApplyState.pendingReload.concat(ApplyState.pendingRestart), []);
        Config.set("bar.screens", ["DP-2"]);
        Config.set("notifications.server", false);
        Config.set("bar.height", 40);
        eq("reload setting pending", ApplyState.pendingReload, ["bar.screens"]);
        eq("restart setting pending", ApplyState.pendingRestart, ["notifications.server"]);
        eq("status()", [ApplyState.status("bar.height"), ApplyState.status("bar.screens")], ["applied", "reload"]);
        Config.resetAll();
        eq("reverting clears pending", ApplyState.pendingReload.concat(ApplyState.pendingRestart), []);
    }

    function testCompositor() {
        eq("compositor detection", Compositor.kind, Compositor.detected === "hyprland" || Compositor.detected === "niri" ? Compositor.detected : "none");
        check("capabilities is an object", typeof Compositor.capabilities === "object");
        if (Compositor.kind === "none")
            check("null backend refuses actions", Compositor.focusWorkspace(1) === false && !Compositor.supports("workspaces"));
        else
            check("backend exposes monitors", Array.isArray(Compositor.monitors));
    }

    // Minimize: backend-neutral state (Compositor/Minimize.js), the dock's
    // choice and the overview's filter. No compositor actions are sent.
    function testMinimize() {
        for (const c of ["minimizeWindow", "restoreWindow", "minimizedWindowState"])
            check("capability declared: " + c, typeof Compositor.capabilities[c] === "boolean");
        if (Compositor.kind === "none")
            check("minimize refused without support", Compositor.minimizeWindow("0x1") === false && Compositor.restoreWindow("0x1") === false);
        const mons = [{ name: "A", focused: true, activeWorkspaceId: 1 }, { name: "B", focused: false, activeWorkspaceId: 5 }];
        const wss = [{ id: 1, name: "1", monitor: "A", special: false }, { id: 3, name: "3", monitor: "A", special: false }, { id: 5, name: "5", monitor: "B", special: false }, { id: -99, name: "special:magic", monitor: "A", special: true }];
        const w = (id, ws, mon, extra) => Object.assign({ id: id, appId: "app", workspaceId: ws, workspaceName: String(ws), monitor: mon, minimized: false, minimizedAt: 0 }, extra || {});
        // Minimize remembers where each window was.
        let store = Minimize.remember({}, w("a", 3, "A"), false, 100);
        store = Minimize.remember(store, w("b", 5, "B"), true, 200);
        store = Minimize.remember(store, w("c", -99, "A", { workspaceName: "special:magic" }), false, 300);
        eq("minimize: record", store.a, { workspaceId: 3, workspaceName: "3", monitor: "A", pinned: false, at: 100 });
        check("minimize: pin remembered", store.b.pinned === true);
        // Restore: original workspace, also on the other monitor, also a user special one.
        eq("restore to original workspace", Minimize.restoreTarget(store.a, wss, mons, null), { workspaceId: 3, workspaceName: "3", monitor: "A", create: false });
        eq("restore on second monitor", Minimize.restoreTarget(store.b, wss, mons, null), { workspaceId: 5, workspaceName: "5", monitor: "B", create: false });
        eq("restore to user's special workspace", Minimize.restoreTarget(store.c, wss, mons, null).workspaceName, "special:magic");
        // A dropped (empty) workspace is created again on the window's monitor,
        // or on the focused one when that monitor is gone.
        eq("restore: workspace gone -> recreated on its monitor", Minimize.restoreTarget({ workspaceId: 7, workspaceName: "7", monitor: "B" }, wss, mons, null), { workspaceId: 7, workspaceName: "7", monitor: "B", create: true });
        eq("restore: monitor gone -> recreated on focused monitor", Minimize.restoreTarget({ workspaceId: 9, workspaceName: "9", monitor: "Z" }, wss, mons, null), { workspaceId: 9, workspaceName: "9", monitor: "A", create: true });
        eq("restore: named workspace gone -> recreated", Minimize.restoreTarget({ workspaceId: -1337, workspaceName: "web", monitor: "A" }, wss, mons, null).workspaceName, "web");
        eq("restore: user special gone -> its monitor's workspace", Minimize.restoreTarget({ workspaceId: -97, workspaceName: "special:gone", monitor: "B" }, wss, mons, null), { workspaceId: 5, workspaceName: "5", monitor: "B", create: false });
        eq("restore without record -> focused monitor", Minimize.restoreTarget(null, wss, mons, mons[1]).workspaceId, 5);
        // State comes from the compositor (isMinimized), the monitor from the record.
        const live = Minimize.annotate([w("a", -98, "B"), w("b", -98, "A"), w("d", 1, "A")], store, x => x.workspaceId === -98);
        eq("minimized flags", live.map(x => x.minimized), [true, true, false]);
        eq("minimized window listed on its return monitor", live.map(x => x.monitor), ["A", "B", "A"]);
        eq("minimizedAt", live.map(x => x.minimizedAt), [100, 200, 0]);
        // Closing a minimized window forgets it; a fresh record waits for the compositor.
        eq("restored elsewhere forgotten after grace", Object.keys(Minimize.prune(store, ["a", "b"], ["a", "b", "c"], 10000, 3000, false)), ["a", "b"]);
        eq("fresh record survives until moved", Object.keys(Minimize.prune(store, [], ["a", "b", "c"], 250, 3000, false)), ["a", "b", "c"]);
        eq("incomplete window list keeps records (shell start)", Object.keys(Minimize.prune(store, [], [], 10000, 3000, false)), ["a", "b", "c"]);
        eq("closed minimized window forgotten once list is complete", Object.keys(Minimize.prune(store, ["a"], ["a", "x"], 10000, 3000, true)), ["a"]);
        eq("restored elsewhere forgotten", Object.keys(Minimize.forget(store, "a")), ["b", "c"]);
        // Dock: focus/cycle shown windows; all minimized -> latest minimized comes back.
        const shownAndMin = [w("x", 1, "A"), w("y", -98, "A", { minimized: true, minimizedAt: 50 }), w("z", 1, "A")];
        eq("dock focuses a shown window", Minimize.dockActivation(shownAndMin, ""), { id: "x", restore: false });
        eq("dock cycles shown windows only", Minimize.dockActivation(shownAndMin, "x"), { id: "z", restore: false });
        eq("dock cycle wraps past minimized", Minimize.dockActivation(shownAndMin, "z"), { id: "x", restore: false });
        const allMin = [w("p", -98, "A", { minimized: true, minimizedAt: 10 }), w("q", -98, "A", { minimized: true, minimizedAt: 30 })];
        eq("dock restores latest minimized", Minimize.dockActivation(allMin, ""), { id: "q", restore: true });
        eq("dock: closed app has nothing", Minimize.dockActivation([], ""), null);
        const dockEntries = DockModel.build(["app"], allMin, true, id => ({ id: id }), id => ({ id: id }));
        check("dock: minimized app still running", dockEntries.length === 1 && dockEntries[0].windows.length === 2);
        // Overview: minimized windows only in "all" (dimmed) and "minimized", never in a workspace.
        const ov = [w("m", -98, "A", { minimized: true }), w("n", 1, "A"), w("o", 5, "B")];
        eq("overview all includes minimized", OverviewLayout.visible(ov, "A", null).map(x => x.id), ["m", "n"]);
        eq("overview workspace excludes minimized", OverviewLayout.visible(ov, "A", 1).map(x => x.id), ["n"]);
        eq("overview minimized view", OverviewLayout.visible(ov, "A", "minimized").map(x => x.id), ["m"]);
        eq("overview per monitor", OverviewLayout.visible(ov, "B", "minimized").length, 0);
        if (Compositor.kind === "hyprland") {
            const b = Compositor.backend;
            eq("hyprland selectors", [b.workspaceSelector(3, "3"), b.workspaceSelector(-99, "special:magic"), b.workspaceSelector(-1337, "web")], ["3", "special:magic", "name:web"]);
            check("own special workspace", b.minimizedWorkspace === "special:bifrost-minimized");
            check("minimized state reported", Compositor.windows.every(x => typeof x.minimized === "boolean"));
        }
    }

    // Async: an external edit of config.json must reach Config via the watcher.
    function testWatcher() {
        externalWriter.path = Paths.configFile;
        externalWriter.write(JSON.stringify({ version: 1, values: { bar: { height: 57 } } }));
        watchTimeout.start();
    }

    Connections {
        target: Config
        enabled: watchTimeout.running

        function onSettingChanged(key, value) {
            if (key === "bar.height" && value === 57) {
                watchTimeout.stop();
                test.check("external edit is picked up live", true);
                test.finish();
            }
        }
    }

    Timer {
        id: appsWait

        property int tries: 0

        interval: 200
        repeat: true
        onTriggered: {
            tries++;
            if (Apps.all.length > 0 || tries > 25) {
                stop();
                test.testApps();
                test.testCtl();
            }
        }
    }

    Timer {
        id: watchTimeout

        interval: 3000
        onTriggered: {
            test.check("external edit is picked up live", false, "no change within 3 s");
            test.finish();
        }
    }

    // Async part of testBarMenus: hover opened the menu; a click keeps it, the
    // next one closes it.
    Timer {
        id: hoverCheck

        interval: 400
        onTriggered: {
            const c = test.hoverCase;
            test.check("hover over the anchor opens the menu", c.menu.isOpen && c.menu.openedByHover && c.host.shown === c.menu);
            c.menu.click();
            test.check("a click on a hover-opened menu keeps it open", c.menu.isOpen && !c.menu.openedByHover);
            c.menu.click();
            test.check("the next click closes it", !c.menu.isOpen && c.host.shown === null);
            Config.set("bar.menus.openOnHover", false);
            const passive = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/BarMenu.qml")).createObject(test, { bar: c.bar, anchorItem: c.anchor, grabFocus: false });
            test.check("hover off: a pointer-following menu (system status) doesn't open on hover either", passive.openOnHover === false);
            const details = Qt.createComponent(Qt.resolvedUrl("Modules/Bar/SystemStatusPopup.qml")).createObject(test, { bar: c.bar, anchorItem: c.anchor });
            test.check("hover off: system status opens by click and grabs focus", details !== null && details.grabFocus === true && details.openOnHover === false);
            Config.set("bar.menus.openOnHover", true);
            test.check("hover on: system status follows the pointer", details.grabFocus === false && details.openOnHover === true);
            Config.reset("bar.menus.openOnHover");
            for (const o of [c.menu, c.anchor, c.bar, c.host, passive, details])
                o.destroy();
            test.hoverCase = null;
            if (test.finishPending)
                test.finish();
        }
    }

    function finish() {
        if (hoverCase || stdinPending || optionalPending) {
            finishPending = true;
            return;
        }
        console.info("SELFTEST DONE pass=" + passed + " fail=" + failed);
    }

    JsonReader {
        id: reader
    }

    WatchedFile {
        id: presetWriter

        watch: false
    }

    WatchedFile {
        id: externalWriter

        watch: false
    }

    // Give the config watcher time to arm (it creates the directory first).
    Timer {
        interval: 600
        running: true
        onTriggered: {
            if (!Platform.env("BIFROST_CONFIG_DIR")) {
                console.info("FAIL refusing to run without BIFROST_CONFIG_DIR (would touch the real config)");
                test.failed++;
                test.finish();
                return;
            }
            Exec.run(["python3", "-c", "import sys; print(sys.stdin.readline().strip()[::-1])"], (code, out) => {
                test.check("Exec stdin reaches child without argv", code === 0 && out.trim() === "fedcba");
                test.stdinPending = false;
                if (test.finishPending) test.finish();
            }, 3000, test, "abcdef\n");
            Exec.runOptional(["bifrost-selftest-nonexistent-tool"], (code) => {
                test.check("missing optional command completes with 127", code === 127);
                Exec.runOptional(["bifrost-selftest-nonexistent-tool"], (cached) => {
                    test.check("missing optional command cached", cached === 127 && Exec.missingTools["bifrost-selftest-nonexistent-tool"] === true);
                    Exec.runOptional(["printf", "%s", "literal $HOME; $(false)"], (ok, out) => {
                        test.check("optional command preserves argv", ok === 0 && out === "literal $HOME; $(false)");
                        test.optionalPending = false;
                        if (test.finishPending) test.finish();
                    });
                });
            });
            test.testLogic();
            test.testSchema();
            test.testConfig();
            test.testSun();
            test.testMigrations();
            test.testTheme();
            test.testComponents();
            test.testGroupedSettings();
            test.testEditors();
            test.prepareRowLayoutTests();
            test.testBar();
            test.testBarMenus();
            test.testPhase5();
            test.testPhase6();
            test.testPhase7();
            test.testApplyState();
            test.testCompositor();
            test.testMinimize();
            appsWait.start();
        }
    }
}
