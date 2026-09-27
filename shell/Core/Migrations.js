.pragma library

// Upgrades config.json documents written by older Bifrost versions.
// Each step takes a doc at version N and returns it at version N + 1.
// Config saves the original to backups/ before writing a migrated doc back.
const steps = {
    // 1 → 2: appearance.variant (dark|light|auto) became appearance.mode
    // (light|dark|system|auto). A stray top-level "appearance" object written
    // by an early build outside "values" is dropped.
    1: function (doc) {
        const a = doc.values && doc.values.appearance;
        if (a && "variant" in a) {
            if (!("mode" in a))
                a.mode = a.variant;
            delete a.variant;
        }
        delete doc.appearance;
        doc.version = 2;
        return doc;
    },
    // 2 → 3: one glass & materials system (schema/materials.json) replaces
    // appearance.transparency/glass/borders/shadows, bar.radius and the
    // compositor blur radius/passes.
    2: function (doc) {
        const v = doc.values || {};
        const a = v.appearance || {};
        const m = v.materials || {};
        const put = (surface, prop, value) => {
            if (value === undefined || value === null)
                return;
            m[surface] = m[surface] || {};
            if (!(prop in m[surface]))
                m[surface][prop] = value;
        };
        const tr = a.transparency || {};
        put("bar", "transparency", tr.bar);
        put("dock", "transparency", tr.dock);
        for (const s of ["menus", "launcher", "controlCenter", "notifications", "settings", "osd"])
            put(s, "transparency", tr.windows);
        const g = a.glass || {};
        put("all", "grain", g.grain);
        if (g.blur === false)
            put("all", "blur", false);
        const b = a.borders || {};
        if (b.enabled === false)
            put("all", "border", false);
        if (typeof b.opacityScale === "number")
            put("all", "borderOpacity", Math.round(16 * b.opacityScale));
        if (a.shadows && a.shadows.enabled === false)
            put("all", "shadow", 0);
        if (v.bar && typeof v.bar.radius === "number")
            put("bar", "radius", v.bar.radius);
        const hb = v.hyprland && v.hyprland.blur;
        if (hb && typeof hb.size === "number")
            m.blurStrength = Math.max(1, Math.min(100, Math.round((hb.size - 1) / 0.39)));
        delete a.transparency;
        delete a.glass;
        delete a.borders;
        delete a.shadows;
        if (v.bar)
            delete v.bar.radius;
        if (v.hyprland)
            delete v.hyprland.blur;
        if (Object.keys(m).length)
            v.materials = m;
        doc.version = 3;
        return doc;
    },
    // 3 → 4: bar "islands" style became background + widget style, and the
    // system status Boxed/Integrated choice now applies to every widget.
    3: function (doc) {
        const bar = (doc.values || {}).bar;
        if (bar) {
            if (bar.style === "islands") {
                bar.style = "floating";
                if (!("background" in bar))
                    bar.background = "none";
                if (!("widgetStyle" in bar))
                    bar.widgetStyle = "grouped";
            }
            const ss = bar.systemStatus;
            if (ss && "appearance" in ss) {
                if (ss.appearance === "boxed" && !("widgetStyle" in bar))
                    bar.widgetStyle = "boxed";
                delete ss.appearance;
            }
        }
        doc.version = 4;
        return doc;
    },
    // 4 → 5: background blur is an amount per surface (0 = off) instead of
    // on/off per surface plus one materials.blurStrength. On keeps the old
    // strength, so nothing changes on screen.
    4: function (doc) {
        const m = (doc.values || {}).materials;
        if (m) {
            const strength = typeof m.blurStrength === "number" ? m.blurStrength : null;
            for (const id in m) {
                const s = m[id];
                if (!s || typeof s !== "object" || !("blur" in s))
                    continue;
                if (s.blur === false)
                    s.blur = 0;
                else if (s.blur === true)
                    s.blur = strength !== null ? strength : 20;
            }
            if (strength !== null) {
                m.all = m.all || {};
                if (!("blur" in m.all))
                    m.all.blur = strength;
            }
            delete m.blurStrength;
        }
        doc.version = 5;
        return doc;
    },
    // 5 → 6: one glass for every surface (materials.transparency/blur/tint/
    // border) instead of per-surface overrides with link/unlink. All
    // surfaces' values are kept; the rest take the standard glass. The prism
    // switch (intensity 0 = off), the spacing scale (→ density) and app
    // window transparency are gone, and so is the Settings layout page
    // (settingsUI). Same in bifrostctl (migrate_5).
    5: function (doc) {
        const v = doc.values || {};
        const m = v.materials;
        if (m && typeof m === "object") {
            const all = m.all && typeof m.all === "object" ? m.all : {};
            const out = {};
            for (const k of ["transparency", "blur", "tint", "border"])
                if (all[k] !== null && all[k] !== undefined)
                    out[k] = all[k];
            if (out.blur === true || out.blur === false)
                out.blur = out.blur ? 20 : 0;
            v.materials = out;
        }
        const a = v.appearance;
        if (a && typeof a === "object") {
            if (a.prism && typeof a.prism === "object" && "enabled" in a.prism) {
                if (a.prism.enabled === false)
                    a.prism.intensity = 0;
                delete a.prism.enabled;
                if (!Object.keys(a.prism).length)
                    delete a.prism;
            }
            const scale = a.spacingScale;
            delete a.spacingScale;
            if (typeof scale === "number" && !("density" in a)) {
                if (scale >= 1.2)
                    a.density = "spacious";
                else if (scale <= 0.85)
                    a.density = "compact";
            }
        }
        const w = v.hyprland && v.hyprland.windows;
        if (w && typeof w === "object") {
            delete w.activeTransparency;
            delete w.inactiveTransparency;
            if (!Object.keys(w).length)
                delete v.hyprland.windows;
        }
        delete v.settingsUI;
        doc.version = 6;
        return doc;
    },
    // 6 → 7: the accent and the glass tint are set per light/dark mode, like
    // the foreground. One colour for both becomes the same colour in each.
    // Same in bifrostctl (migrate_6).
    6: function (doc) {
        const v = doc.values || {};
        for (const [section, key] of [["appearance", "accent"], ["materials", "tint"]]) {
            const s = v[section];
            if (s && typeof s[key] === "string")
                s[key] = { light: s[key], dark: s[key] };
            else if (s && s[key] !== undefined && (s[key] === null || typeof s[key] !== "object"))
                delete s[key];
        }
        doc.version = 7;
        return doc;
    }
};

function migrate(doc, target) {
    let v = typeof doc.version === "number" ? doc.version : 1;
    while (v < target) {
        const step = steps[v];
        if (!step)
            throw new Error("no migration from config version " + v);
        doc = step(doc);
        v = doc.version;
    }
    doc.version = v;
    return doc;
}
