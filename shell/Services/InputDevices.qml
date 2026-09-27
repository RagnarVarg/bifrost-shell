pragma Singleton
import QtQuick
import Quickshell
import qs.Core
import qs.Compat
import qs.Compositor

// Shared input state. Discovery belongs to Compositor; edits use Config and
// the existing CompositorSync/generate_hypr path, just like display settings.
Singleton {
    id: root
    property var devices: []
    property var gestures: ({})
    // What a gesture can do, from the central action catalogue
    // (hypr/keybinds.json gestureActions via bifrostctl): [{ value, label }].
    property var gestureActions: []
    property var catalog: ({layouts:[], options:[]})
    property string error: ""
    property var applyStatus: ({})
    property bool busy: false
    property bool loaded: false
    property int consumers: 0
    readonly property var fields: (Schema.def("input.devices") || {}).deviceFields || []
    readonly property var saved: Config.get("input.devices") || ({})
    function retain() { consumers++; refresh(); }
    function release() { consumers = Math.max(0, consumers-1); }
    function refresh() {
        if (busy) return;
        busy = true;
        Compositor.queryInput(data => {
            devices = data.devices || [];
            gestures = data.gestures || {};
            gestureActions = data.gestureActions || [];
            catalog = data.catalog || {layouts:[],options:[]};
            error = data.error || "";
            loaded = true;
            busy = false;
        });
    }
    function byName(name) { return devices.find(d => d.name === name) || null; }
    function value(device, key) {
        if (!device) return undefined;
        const own = saved[device.name];
        return own && own.values[key] !== undefined ? own.values[key] : device.values[key];
    }
    function supported(device, def) {
        if (!device || def.kinds.indexOf(device.kind) < 0) return false;
        if (device.kind === "keyboard") return device.values[def.key] !== undefined;
        if (!def.capability) return device.values[def.key] !== undefined;
        const cap = device.capabilities[def.capability];
        return Array.isArray(cap) ? cap.length > 0 : cap === true;
    }
    function choices(device, def) {
        const cap = device ? device.capabilities[def.capability] : null;
        return (def.options || []).map((v,i) => ({value:v,label:I18n.tr((def.optionLabels || [])[i] || String(v))})).filter(o => !Array.isArray(cap) || cap.indexOf(o.value) >= 0);
    }
    function set(device, key, value) {
        if (!device) return;
        const def = fields.find(f => f.key === key);
        if (!def || !supported(device,def)) return;
        const all = JSON.parse(JSON.stringify(saved));
        const entry = all[device.name] || {kind:device.kind,values:{},original:{}};
        // Snapshot only the fields we own; never overwrite unrelated XKB options.
        if (entry.original[key] === undefined && device.values[key] !== undefined) entry.original[key] = device.values[key];
        entry.values[key] = value;
        all[device.name] = entry;
        error = Config.set("input.devices", all) || "";
    }
    function reset(device, key) {
        const all = JSON.parse(JSON.stringify(saved));
        if (!device || !all[device.name]) return;
        delete all[device.name].values[key];
        delete all[device.name].original[key];
        if (!Object.keys(all[device.name].values).length) delete all[device.name];
        error = Config.set("input.devices",all) || "";
        reloadLater.restart();
    }
    function setGesture(key, action) {
        const next = Object.assign({}, Config.get("input.gestures") || {});
        const current = Object.assign({}, gestures);
        for (const k of Object.keys(next)) current[k] = {action:next[k]};
        const [count, direction] = key.split(":");
        const axis = d => ["left","right","horizontal"].indexOf(d) >= 0 ? "horizontal" : ["up","down","vertical"].indexOf(d) >= 0 ? "vertical" : "";
        if (action !== "none") for (const k of Object.keys(current)) {
            const [n,d] = k.split(":");
            if (k === key || n !== count) continue;
            const sameAxis = axis(d) && axis(d) === axis(direction) && (d === axis(d) || direction === axis(direction));
            if (sameAxis || (d === "swipe" && axis(direction)) || (direction === "swipe" && axis(d))) next[k] = "none";
        }
        next[key] = action;
        error = Config.set("input.gestures",next) || "";
    }
    function setOption(device, prefix, option) {
        const current = String(value(device,"kb_options") || "").split(",").filter(Boolean);
        const next = current.filter(s => !s.startsWith(prefix) && !(prefix === "caps:" && s === "ctrl:nocaps"));
        if (option) next.push(option);
        set(device,"kb_options",next.join(","));
    }
    function option(device, prefix) {
        return String(value(device,"kb_options") || "").split(",").find(s => s.startsWith(prefix) || (prefix === "caps:" && s === "ctrl:nocaps")) || "";
    }
    WatchedFile {
        path: root.consumers > 0 ? Paths.runtimeDir + "/compositor.json" : ""
        onContentChanged: (text,exists) => { try { root.applyStatus = exists ? JSON.parse(text) : {}; } catch(e) {} }
    }
    Timer { interval: 10000; repeat: true; running: root.consumers > 0; onTriggered: root.refresh() }
    Timer { id: reloadLater; interval: 1000; onTriggered: root.refresh() }
    Connections {
        target: Compositor
        function onEvent(name,data) { if (root.consumers > 0 && (name === "config-reloaded" || name === "input")) reloadLater.restart(); }
    }
}
