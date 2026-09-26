.pragma library

// Builds dock entries from pinned desktop ids and open windows.
//   pinned:  ["vivaldi-stable", ...]
//   windows: Compositor.windows
//   resolve: appId -> app (Apps.forAppId) ; byId: id -> app (Apps.byId)
// Returns [{ key, app, pinned, windows: [...] }] with pinned first (in order),
// then running unpinned apps in first-seen order.
function build(pinned, windows, showRunning, resolve, byId) {
    const groups = {};
    const order = [];
    for (const w of windows) {
        const app = resolve(w.appId);
        const key = app ? app.id : "window:" + (w.appId || w.id);
        if (!groups[key]) {
            groups[key] = { key: key, app: app, windows: [] };
            order.push(key);
        }
        groups[key].windows.push(w);
    }
    const out = [];
    for (const id of pinned) {
        const g = groups[id];
        const app = g ? g.app : byId(id);
        if (!app && !g)
            continue;
        out.push({ key: id, app: app, pinned: true, windows: g ? g.windows : [] });
    }
    if (showRunning)
        for (const key of order)
            if (pinned.indexOf(key) < 0)
                out.push({ key: key, app: groups[key].app, pinned: false, windows: groups[key].windows });
    return out;
}

function moved(list, id, delta) {
    const i = list.indexOf(id);
    const j = i + delta;
    if (i < 0 || j < 0 || j >= list.length)
        return list;
    const next = list.slice();
    next.splice(i, 1);
    next.splice(j, 0, id);
    return next;
}

function withLauncher(items, enabled, index) {
    if (!enabled) return items;
    const out = items.slice();
    out.splice(Math.max(0,Math.min(out.length,index || 0)),0,{key:"bifrost-launcher",kind:"launcher",app:null,pinned:false,windows:[]});
    return out;
}

// Keep delegates (hover state, popup and capture) alive across compositor polls.
function syncKeys(model, keys) {
    for (let i=model.count-1; i>=0; --i)
        if (keys.indexOf(model.get(i).entryKey) < 0) model.remove(i);
    for (let i=0; i<keys.length; ++i) {
        if (i < model.count && model.get(i).entryKey === keys[i]) continue;
        let found=-1;
        for (let j=i+1; j<model.count; ++j)
            if (model.get(j).entryKey === keys[i]) { found=j; break; }
        if (found >= 0) model.move(found,i,1);
        else model.insert(i,{entryKey:keys[i]});
    }
}

// Persist an explicit app order without turning running apps into pins.
function ordered(items, order) {
    const ranks = order || [];
    return items.map((item, index) => ({item, index})).sort((a,b) => {
        const ai=ranks.indexOf(a.item.key), bi=ranks.indexOf(b.item.key);
        return (ai < 0 ? ranks.length+a.index : ai) - (bi < 0 ? ranks.length+b.index : bi);
    }).map(e => e.item);
}
function dropOrder(keys, key, before) {
    const out=keys.filter(k => k !== key);
    const index=before ? out.indexOf(before) : out.length;
    out.splice(index < 0 ? out.length : index,0,key);
    return out;
}
function rememberOrder(previous, visible) {
    return visible.concat((previous || []).filter(k => visible.indexOf(k) < 0));
}
