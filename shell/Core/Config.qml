pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import "ConfigLogic.js" as L
import "Migrations.js" as Migrations

// Resolved configuration shared by the shell and Bifrost Settings.
//
//   values = schema defaults ⊕ preset ⊕ user overrides (~/.config/bifrost/config.json)
//
// config.json is sparse: it only holds values that differ from the layers
// below, so resetting a setting means deleting its key. Both processes watch
// the file, which makes it the single channel for persistent changes.
//
// Bind to `Config.values.<section>.<key>`; the object is replaced on every
// change so bindings re-evaluate.
Singleton {
    id: root

    readonly property int formatVersion: 8
    readonly property int writeDelayMs: 80

    property bool ready: false
    property var values: ({})
    property var base: ({})          // defaults ⊕ preset (what "reset" returns to)
    property var overrides: ({})     // validated user values
    property var presetValues: ({})
    // Runtime-only values over everything, never written to config.json
    // (the login screen's larger text / high contrast). setTransient().
    property var transientValues: ({})
    property string preset: "default"
    property int revision: 0

    property var doc: ({ version: formatVersion, values: {} })   // file contents, unknown keys kept
    property var issues: []          // [{ kind: "invalid"|"unknown"|"preset", key, message }]
    property string loadError: ""    // set when config.json is not valid JSON
    readonly property bool writable: loadError === ""

    // Env override for testing a preset without touching config.json.
    readonly property string presetOverride: Platform.env("BIFROST_PRESET") || ""

    property string _lastText: ""

    signal settingChanged(string key, var value)

    // ── Reading ──────────────────────────────────────────────────────────
    function get(key: string): var {
        return L.deepGet(values, key);
    }

    function defaultOf(key: string): var {
        return L.deepGet(Schema.defaults, key);
    }

    function baseOf(key: string): var {
        return L.deepGet(base, key);
    }

    function isModified(key: string): bool {
        return L.deepGet(overrides, key) !== undefined;
    }

    function isFromPreset(key: string): bool {
        return L.deepGet(presetValues, key) !== undefined;
    }

    function applyModeOf(key: string): string {
        const d = Schema.def(key);
        return d ? d.apply : "live";
    }

    function modifiedKeys(sectionId: string): var {
        const ks = sectionId ? Schema.keysInSection(sectionId) : Schema.keys;
        return ks.filter(k => isModified(k));
    }

    // ── Writing ── all return "" on success or an error message ─────────
    function set(key: string, value): string {
        const d = Schema.def(key);
        if (!d)
            return "unknown setting '" + key + "'";
        if (!writable)
            return "config.json is invalid, fix it first: " + loadError;
        const c = L.coerce(d, value);
        if (!c.ok)
            return c.error;
        const next = L.clone(doc);
        if (L.equals(c.value, baseOf(key)))
            L.deepDelete(next.values, key);
        else
            L.deepSet(next.values, key, c.value);
        return commit(next);
    }

    // value undefined = remove. Validated like any value.
    function setTransient(key: string, value): string {
        const next = L.clone(transientValues);
        if (value === undefined) {
            L.deepDelete(next, key);
        } else {
            const d = Schema.entries[key];
            const r = d ? L.coerce(d, value) : { ok: false, error: "unknown setting" };
            if (!r.ok)
                return r.error;
            L.deepSet(next, key, r.value);
        }
        transientValues = next;
        resolve();
        return "";
    }

    function reset(key: string): string {
        if (!Schema.def(key))
            return "unknown setting '" + key + "'";
        const next = L.clone(doc);
        L.deepDelete(next.values, key);
        return commit(next);
    }

    function resetSection(sectionId: string): string {
        const ks = Schema.keysInSection(sectionId);
        if (!ks.length)
            return "unknown section '" + sectionId + "'";
        const next = L.clone(doc);
        for (const k of ks)
            L.deepDelete(next.values, k);
        return commit(next);
    }

    // Resets several keys in one write (e.g. every property of one surface).
    function resetKeys(keys: var): string {
        const next = L.clone(doc);
        for (const k of keys)
            L.deepDelete(next.values, k);
        return commit(next);
    }

    function resetAll(): string {
        const next = L.clone(doc);
        next.values = {};
        return commit(next);
    }

    function setPreset(id: string): string {
        const next = L.clone(doc);
        if (id === "default")
            delete next.preset;
        else
            next.preset = id;
        return commit(next);
    }

    // Writes pending changes synchronously (e.g. before a reload).
    function flush() {
        if (writeTimer.running) {
            writeTimer.stop();
            write(true);
        }
    }

    function commit(next): string {
        if (!writable)
            return "config.json is invalid, fix it first: " + loadError;
        doc = next;
        resolve();
        writeTimer.restart();
        return "";
    }

    function write(sync) {
        const out = { version: formatVersion };
        if (doc.preset)
            out.preset = doc.preset;
        out.values = doc.values || {};
        for (const k in doc)
            if (!(k in out))
                out[k] = doc[k];
        const text = JSON.stringify(out, null, 2) + "\n";
        if (text === _lastText)
            return;
        _lastText = text;
        if (sync)
            file.writeNow(text);
        else
            file.write(text);
    }

    // ── Loading / resolving ─────────────────────────────────────────────
    function parse(text: string, missing: bool) {
        if (!missing && text === _lastText)
            return;
        _lastText = missing ? "" : text;
        if (missing || text.trim() === "") {
            loadError = "";
            doc = { version: formatVersion, values: {} };
        } else {
            let parsed;
            try {
                parsed = JSON.parse(text);
            } catch (e) {
                // Keep the last good state and refuse to overwrite the user's file.
                loadError = e.message;
                console.error("[bifrost] config.json:", e.message);
                return;
            }
            if (!L.isPlainObject(parsed)) {
                loadError = "top level must be an object";
                return;
            }
            const version = typeof parsed.version === "number" ? parsed.version : formatVersion;
            if (version > formatVersion) {
                loadError = "config.json is version " + version + ", newer than this Bifrost (" + formatVersion + ")";
                return;
            }
            if (!L.isPlainObject(parsed.values))
                parsed.values = {};
            if (version < formatVersion) {
                try {
                    parsed = Migrations.migrate(parsed, formatVersion);
                } catch (e) {
                    loadError = e.message;
                    return;
                }
                backup.path = Paths.backupsDir + "/config.v" + version + "." + Date.now() + ".json";
                backup.write(text);
                writeTimer.restart();
            }
            loadError = "";
            doc = parsed;
        }
        resolve();
    }

    function loadPreset(id) {
        if (id === "default")
            return { values: {}, issues: [] };
        for (const dir of [Paths.userPresetsDir, Paths.presetsDir]) {
            const res = reader.read(dir + "/" + id + ".json");
            if (res.ok)
                return { values: (res.data && res.data.values) || {}, issues: [] };
            if (!res.missing)
                return { values: {}, issues: [{ kind: "preset", key: "", message: res.error }] };
        }
        return { values: {}, issues: [{ kind: "preset", key: "", message: "preset '" + id + "' not found" }] };
    }

    // Keeps only the entries of `tree` that are known keys with valid values.
    function validated(tree, kind, found) {
        const out = {};
        for (const key of Schema.keys) {
            const raw = L.deepGet(tree, key);
            if (raw === undefined)
                continue;
            const c = L.coerce(Schema.entries[key], raw);
            if (c.ok)
                L.deepSet(out, key, c.value);
            else
                found.push({ kind: "invalid", key: key, message: kind + ": " + c.error });
        }
        for (const key of L.unknownKeys(tree, Schema.entries, ""))
            found.push({ kind: "unknown", key: key, message: kind + ": unknown setting '" + key + "' (kept in file)" });
        return out;
    }

    function resolve() {
        if (!Schema.ready)
            return;
        const found = [];
        preset = presetOverride || doc.preset || "default";
        const p = loadPreset(preset);
        found.push.apply(found, p.issues);

        const pv = validated(p.values, "preset " + preset, found);
        const ov = validated(doc.values || {}, "config.json", found);
        const nextBase = L.merge(Schema.defaults, pv, Schema.leafKeys, "");
        const nextValues = L.merge(L.merge(nextBase, ov, Schema.leafKeys, ""), transientValues, Schema.leafKeys, "");

        const changed = [];
        if (ready)
            for (const key of Schema.keys)
                if (!L.equals(L.deepGet(values, key), L.deepGet(nextValues, key)))
                    changed.push(key);

        presetValues = pv;
        overrides = ov;
        base = nextBase;
        values = nextValues;
        issues = found;
        revision++;
        ready = true;

        for (const key of changed)
            settingChanged(key, L.deepGet(nextValues, key));
    }

    Timer {
        id: writeTimer
        interval: root.writeDelayMs
        onTriggered: root.write(false)
    }

    JsonReader {
        id: reader
    }

    WatchedFile {
        id: backup

        watch: false
    }

    WatchedFile {
        id: file

        path: Paths.configFile
        onContentChanged: (content, exists) => root.parse(content, !exists)
    }

    Component.onCompleted: {
        // The initial load may have run before Schema was ready; parse again.
        const content = file.readNow();
        _lastText = "";
        parse(content === null ? "" : content, content === null);
    }
}
