pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import qs.Compositor
import "ConfigLogic.js" as L

// Loads schema/index.json + one file per section. The schema is the single
// source of truth for every setting: type, default, bounds, labels, where it
// lives in Settings, its scope and how it is applied.
Singleton {
    id: root

    readonly property var applyModes: ["live", "reload", "restart"]
    readonly property var scopes: ["shell", "hyprland", "system"]
    readonly property var nullableTypes: ["bool", "int", "real", "color", "string", "font", "icon", "path"]

    property bool ready: false
    property var categories: []   // [{ id, label, icon, advanced, pages: [{ id, label, icon, page }] }]
    property var sections: []     // [{ id, label, icon, category, description, settings: [def] }]
    property var entries: ({})    // key -> def (def.section added)
    property var keys: []         // ordered
    property var defaults: ({})   // nested tree of defaults
    property var leafKeys: ({})   // keys whose values are objects but must not be deep-merged
    property var errors: []

    function def(key: string): var {
        return entries[key] || null;
    }

    function section(id: string): var {
        return sections.find(s => s.id === id) || null;
    }

    function keysInSection(id: string): var {
        const s = section(id);
        return s ? s.settings.map(d => d.key) : [];
    }

    // A section is shown when at least one of its settings is supported.
    function isSectionSupported(id: string): bool {
        const s = section(id);
        return s !== null && !s.hidden && keysInSection(id).some(k => isSupported(k));
    }

    function groupLabel(sectionId: string, group: string): string {
        const s = section(sectionId);
        return s && s.groups[group] ? s.groups[group] : group;
    }

    function optionLabel(key: string, option: string): string {
        const d = def(key);
        return d && d.optionLabels && d.optionLabels[option] ? d.optionLabels[option] : option;
    }

    // Whether a setting applies to the running compositor. Schema entries (or
    // their section) can declare
    //   "requires": { "compositor": ["hyprland"], "capability": "surfaceBlur" }
    // Settings hides unsupported entries; values stay in config untouched.
    function isSupported(key: string): bool {
        const d = def(key);
        const r = d ? d.requires : null;
        if (!r)
            return true;
        if (r.compositor && r.compositor.indexOf(Compositor.kind) < 0)
            return false;
        if (r.capability && !Compositor.supports(r.capability))
            return false;
        return true;
    }

    function sectionsInCategory(id: string): var {
        return sections.filter(s => s.category === id);
    }

    // Settings search index: matches key, label, description and section label.
    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (!q)
            return [];
        const out = [];
        for (const key of keys) {
            const d = entries[key];
            const s = section(d.section);
            const hay = [key, d.label || "", d.description || "", s ? s.label : ""].join(" ").toLowerCase();
            const idx = hay.indexOf(q);
            if (idx >= 0)
                out.push({ key: key, label: d.label, section: d.section, score: (d.label || "").toLowerCase().startsWith(q) ? 0 : 1 + idx });
        }
        return out.sort((a, b) => a.score - b.score);
    }

    // Same as bifrostctl expand_template: one setting per instance and
    // property. The first instance is the global one (its own defaults); the
    // others default to null = inherit the global value (inheritKey).
    function expandTemplate(t) {
        if (!t)
            return [];
        const out = [];
        const first = t.instances[0].id;
        for (const inst of t.instances) {
            for (const prop of t.settings) {
                const d = {};
                for (const k in prop)
                    if (k !== "key" && k !== "globalDefault")
                        d[k] = prop[k];
                d.key = t.prefix + "." + inst.id + "." + prop.key;
                d.instance = inst.id;
                d.prop = prop.key;
                d.group = inst.id;
                if (inst.id === first) {
                    d.default = prop.globalDefault === undefined ? null : prop.globalDefault;
                    d.nullable = d.default === null || prop.nullable === true;
                } else {
                    d.default = null;
                    d.nullable = true;
                    d.inheritKey = t.prefix + "." + first + "." + prop.key;
                }
                out.push(d);
            }
        }
        return out;
    }

    // Schema texts are English; shown in the system language (I18n).
    function localize(sec) {
        const t = v => typeof v === "string" && v !== "" ? I18n.tr(v) : v;
        sec.label = t(sec.label);
        sec.description = t(sec.description);
        for (const g in sec.groups || {})
            sec.groups[g] = t(sec.groups[g]);
        for (const inst of sec.template ? sec.template.instances : []) {
            inst.label = t(inst.label);
            inst.description = t(inst.description);
        }
        for (const d of (sec.settings || []).concat(sec.template ? sec.template.settings : [])) {
            d.label = t(d.label);
            d.description = t(d.description);
            for (const o in d.optionLabels || {})
                d.optionLabels[o] = t(d.optionLabels[o]);
        }
    }

    function load() {
        const errs = [];
        const idx = reader.read(Paths.schemaDir + "/index.json");
        if (!idx.ok) {
            errors = [idx.error];
            console.error("[bifrost] schema:", idx.error);
            return;
        }

        const secs = [];
        const ents = {};
        const order = [];
        const leaves = {};
        let defs = {};

        for (const ref of idx.data.sections || []) {
            const res = reader.read(Paths.schemaDir + "/" + ref.file);
            if (!res.ok) {
                errs.push(res.error);
                continue;
            }
            const sec = res.data;
            localize(sec);
            sec.category = ref.category || sec.category || "shell";
            const settings = [];
            for (const raw of (sec.settings || []).concat(expandTemplate(sec.template))) {
                const d = Object.assign({ scope: "shell", apply: "live", advanced: false, nullable: false }, raw);
                d.section = sec.section;
                if (!d.requires && sec.requires)
                    d.requires = sec.requires;
                const problem = validateDef(d, ents);
                if (problem) {
                    errs.push(problem);
                    continue;
                }
                ents[d.key] = d;
                order.push(d.key);
                settings.push(d);
                if (d.type === "object" || d.type === "widgetLayout")
                    leaves[d.key] = true;
                L.deepSet(defs, d.key, L.clone(d.default));
            }
            secs.push({
                id: sec.section,
                label: sec.label || sec.section,
                icon: sec.icon || "",
                description: sec.description || "",
                category: sec.category,
                groups: sec.groups || {},
                template: sec.template || null,
                page: sec.page || "",
                subpages: sec.subpages || [],
                hidden: sec.hidden === true,
                requires: sec.requires || null,
                settings: settings
            });
        }

        const cats = idx.data.categories || [];
        for (const c of cats) {
            c.label = I18n.tr(c.label || "");
            for (const p of c.pages || [])
                p.label = I18n.tr(p.label || "");
        }
        categories = cats;
        sections = secs;
        entries = ents;
        keys = order;
        leafKeys = leaves;
        defaults = defs;
        errors = errs;
        ready = true;
        for (const e of errs)
            console.error("[bifrost] schema:", e);
    }

    function validateDef(d, existing) {
        if (!d.key || typeof d.key !== "string")
            return "setting without key in section " + d.section;
        if (existing[d.key])
            return d.key + ": duplicate key";
        for (const other in existing)
            if (other.startsWith(d.key + ".") || d.key.startsWith(other + "."))
                return d.key + ": overlaps with " + other;
        if (applyModes.indexOf(d.apply) < 0)
            return d.key + ": invalid apply '" + d.apply + "'";
        if (scopes.indexOf(d.scope) < 0)
            return d.key + ": invalid scope '" + d.scope + "'";
        if (d.nullable && nullableTypes.indexOf(d.type) < 0)
            return d.key + ": type " + d.type + " cannot be nullable";
        if (d.default === null)
            return d.nullable ? "" : d.key + ": null default on non-nullable setting";
        const c = L.coerce(d, d.default);
        if (!c.ok)
            return "default invalid: " + c.error;
        if (!L.equals(c.value, d.default))
            return d.key + ": default " + JSON.stringify(d.default) + " is outside its bounds";
        return "";
    }

    JsonReader {
        id: reader
    }

    Component.onCompleted: load()
}
