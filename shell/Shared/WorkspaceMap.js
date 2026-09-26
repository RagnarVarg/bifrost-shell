.pragma library

// A workspace as a small map: the monitor scaled to `width`, each window at
// its place (Hyprland reports window geometry in the layout's logical pixels,
// monitor size in physical pixels, hence the scale). Windows are clamped to
// the monitor and ordered floating over tiled, like on screen.
//   layout({ x, y, width, height, scale }, [{ id, x, y, width, height, floating }], 440)
//   → { width, height, factor, windows: [{ win, x, y, width, height }] }
function layout(mon, wins, width) {
    const lw = mon && mon.width > 0 ? mon.width / (mon.scale || 1) : 16;
    const lh = mon && mon.height > 0 ? mon.height / (mon.scale || 1) : 9;
    const f = width / lw;
    const ox = mon ? mon.x : 0, oy = mon ? mon.y : 0;
    const out = [];
    for (const w of wins || []) {
        if (!(w.width > 0 && w.height > 0))
            continue;
        const x0 = Math.max(0, w.x - ox), y0 = Math.max(0, w.y - oy);
        const x1 = Math.min(lw, w.x - ox + w.width), y1 = Math.min(lh, w.y - oy + w.height);
        if (x1 <= x0 || y1 <= y0)
            continue;
        out.push({ order: out.length, win: w, x: Math.round(x0 * f), y: Math.round(y0 * f), width: Math.round((x1 - x0) * f), height: Math.round((y1 - y0) * f) });
    }
    // Qt's sort isn't stable: keep the compositor's order among equals.
    out.sort((a, b) => (a.win.floating === true) - (b.win.floating === true) || a.order - b.order);
    return { width: Math.round(width), height: Math.round(lh * f), factor: f, windows: out };
}

// Brings a ListModel of tiles ({ winId, ws, tx, ty, tw, th, order }) in line with a
// layout's windows, in place: rows of windows that are still there are
// updated (only when something changed), gone ones removed, new ones added.
// A delegate therefore lives as long as its window is on the map, and its
// live picture with it; rebuilding the rows on every geometry poll made the
// pictures restart (and show the app icon) several times a second.
function sync(model, windows) {
    const want = {};
    windows.forEach((t, k) => want[t.win.id] = { winId: String(t.win.id), ws: String(t.win.workspaceId), tx: t.x, ty: t.y, tw: t.width, th: t.height, order: k });
    for (let i = model.count - 1; i >= 0; i--)
        if (!(model.get(i).winId in want))
            model.remove(i);
    const have = {};
    for (let i = 0; i < model.count; i++)
        have[model.get(i).winId] = i;
    for (const id in want) {
        const row = want[id];
        if (id in have) {
            const i = have[id], r = model.get(i);
            if (r.ws !== row.ws || r.tx !== row.tx || r.ty !== row.ty || r.tw !== row.tw || r.th !== row.th || r.order !== row.order)
                model.set(i, row);
        } else {
            model.append(row);
        }
    }
}
