.pragma library

// Pure helpers for the Bifrost config model. No QML/Quickshell dependencies so
// they can be exercised by the selftest and mirrored by tools/bifrostctl.

function clone(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function equals(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}

function splitKey(key) {
    return key.split(".");
}

function deepGet(obj, key) {
    const parts = splitKey(key);
    let cur = obj;
    for (let i = 0; i < parts.length; i++) {
        if (!isPlainObject(cur) || !(parts[i] in cur))
            return undefined;
        cur = cur[parts[i]];
    }
    return cur;
}

function deepSet(obj, key, value) {
    const parts = splitKey(key);
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!isPlainObject(cur[parts[i]]))
            cur[parts[i]] = {};
        cur = cur[parts[i]];
    }
    cur[parts[parts.length - 1]] = value;
    return obj;
}

// Removes the key and prunes parents that became empty.
function deepDelete(obj, key) {
    const parts = splitKey(key);
    const trail = [];
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!isPlainObject(cur[parts[i]]))
            return false;
        trail.push([cur, parts[i]]);
        cur = cur[parts[i]];
    }
    const last = parts[parts.length - 1];
    if (!(last in cur))
        return false;
    delete cur[last];
    for (let i = trail.length - 1; i >= 0; i--) {
        const [parent, name] = trail[i];
        if (Object.keys(parent[name]).length === 0)
            delete parent[name];
        else
            break;
    }
    return true;
}

// Merges `top` onto a copy of `bottom`. Values at `leafKeys` (schema keys whose
// type is itself an object, e.g. widget layouts) are replaced, never merged.
function merge(bottom, top, leafKeys, prefix) {
    const out = isPlainObject(bottom) ? clone(bottom) : {};
    if (!isPlainObject(top))
        return out;
    for (const name in top) {
        const path = prefix ? prefix + "." + name : name;
        const tv = top[name];
        if (isPlainObject(tv) && isPlainObject(out[name]) && !(leafKeys && leafKeys[path]))
            out[name] = merge(out[name], tv, leafKeys, path);
        else
            out[name] = clone(tv);
    }
    return out;
}

// Validates/coerces a raw value against a schema definition.
// Returns { ok, value, error }.
function coerce(def, raw) {
    const fail = msg => ({ ok: false, value: undefined, error: def.key + ": " + msg });
    let v = raw;
    // null means "inherit" (typically from the theme) on nullable settings.
    if (v === null)
        return def.nullable ? { ok: true, value: null } : fail("null not allowed");
    switch (def.type) {
    case "bool":
        if (typeof v === "string" && (v === "true" || v === "false"))
            v = v === "true";
        if (typeof v !== "boolean")
            return fail("expected bool");
        return { ok: true, value: v };
    case "int":
    case "real": {
        if (typeof v === "string" && v.trim() !== "")
            v = Number(v);
        if (typeof v !== "number" || !isFinite(v))
            return fail("expected number");
        if (def.type === "int")
            v = Math.round(v);
        if (def.min !== undefined && v < def.min)
            v = def.min;
        if (def.max !== undefined && v > def.max)
            v = def.max;
        return { ok: true, value: v };
    }
    case "enum":
        if (!def.options || def.options.indexOf(v) < 0)
            return fail("expected one of " + JSON.stringify(def.options));
        return { ok: true, value: v };
    case "color":
        if (typeof v !== "string" || !(v === "" || /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v)))
            return fail("expected #RRGGBB, #AARRGGBB or \"\"");
        return { ok: true, value: v };
    case "string":
    case "font":
    case "icon":
    case "path":
        if (typeof v !== "string")
            return fail("expected string");
        if (def.pattern && !(new RegExp(def.pattern)).test(v))
            return fail("invalid format");
        return { ok: true, value: v };
    case "list":
        // Also accept array-likes (e.g. QVariantList from C++ callers).
        if (!Array.isArray(v) && !(v && typeof v === "object" && typeof v.length === "number"))
            return fail("expected list");
        return { ok: true, value: Array.prototype.slice.call(v).map(clone) };
    case "object":
    case "widgetLayout":
        if (!isPlainObject(v))
            return fail("expected object");
        if (def.deviceFields) {
            const result = {};
            for (const name of Object.keys(v)) {
                if (!name || name.length > 256 || /[\x00-\x1f]/.test(name) || ["__proto__", "constructor", "prototype"].indexOf(name) >= 0)
                    return fail("invalid device name");
                const entry = v[name];
                if (!isPlainObject(entry) || ["keyboard", "mouse", "trackpad"].indexOf(entry.kind) < 0 || Object.keys(entry).some(k => ["kind", "values", "original"].indexOf(k) < 0))
                    return fail("invalid device record");
                result[name] = {kind:entry.kind};
                for (const group of ["values", "original"]) {
                    const vals = entry[group] === undefined ? {} : entry[group];
                    if (!isPlainObject(vals)) return fail("invalid device values");
                    result[name][group] = {};
                    for (const prop of Object.keys(vals)) {
                        const fd = def.deviceFields.find(f => f.key === prop && f.kinds.indexOf(entry.kind) >= 0);
                        if (!fd) return fail("unsupported device field");
                        const c = group === "original" && vals[prop] === "" && ["string", "enum"].indexOf(fd.type) >= 0 ? {ok:true, value:""} : coerce(fd, vals[prop]);
                        if (!c.ok) return fail(c.error);
                        result[name][group][prop] = c.value;
                    }
                }
            }
            return {ok:true, value:result};
        }
        if (def.valueOptions && Object.keys(v).some(k => !(new RegExp(def.mapKeyPattern)).test(k) || def.valueOptions.indexOf(v[k]) < 0))
            return fail("invalid map entry");
        return { ok: true, value: clone(v) };
    default:
        return fail("unknown schema type '" + def.type + "'");
    }
}

// Walks an overrides tree and returns dotted paths that don't belong to any
// schema key (stops descending at schema keys).
function unknownKeys(tree, entries, prefix) {
    const out = [];
    if (!isPlainObject(tree))
        return out;
    for (const name in tree) {
        const path = prefix ? prefix + "." + name : name;
        if (entries[path])
            continue;
        if (isPlainObject(tree[name]))
            out.push.apply(out, unknownKeys(tree[name], entries, path));
        else
            out.push(path);
    }
    return out;
}

// Replaces "@a.b.c" string references with values from `root`, recursively.
// Used by the theme resolver so tokens can reference other tokens.
function resolveRefs(node, root, depth) {
    depth = depth || 0;
    if (depth > 16) // reference hops, guards against cycles
        return node;
    if (typeof node === "string" && node.charAt(0) === "@") {
        const target = deepGet(root, node.substring(1));
        return target === undefined ? node : resolveRefs(target, root, depth + 1);
    }
    if (Array.isArray(node))
        return node.map(n => resolveRefs(n, root, depth));
    if (isPlainObject(node)) {
        const out = {};
        for (const k in node)
            out[k] = resolveRefs(node[k], root, depth);
        return out;
    }
    return node;
}
