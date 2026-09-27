.pragma library

// A zoomed-out grid of proportional window pictures, centred in width ×
// height. Each picture is at most maxHeight tall and maxWidth wide, however
// few windows there are, and has `caption` below it. Of the column counts
// that give the largest pictures, the one whose grid best matches the area's
// shape wins (a wide row on an ultrawide screen, a block on 16:9).
function layout(windows, width, height, gap, caption, maxWidth, maxHeight) {
    if (!windows.length || width <= 0 || height <= 0) return [];
    maxWidth = maxWidth > 0 ? Math.min(maxWidth, width) : width;
    maxHeight = maxHeight > 0 ? Math.min(maxHeight, height - caption) : height - caption;
    const size = w => [Math.max(1, w.width || 16), Math.max(1, w.height || 9)];
    let best = [], bestArea = -1, bestShape = Infinity;
    for (let columns = 1; columns <= windows.length; ++columns) {
        const rows = Math.ceil(windows.length / columns);
        const cw = Math.min(maxWidth, (width - gap * (columns - 1)) / columns);
        const ch = Math.min(maxHeight, (height - gap * (rows - 1)) / rows - caption);
        if (cw < 1 || ch < 1) continue;
        const pics = windows.map(w => {
            const [ww, wh] = size(w);
            const k = Math.min(cw / ww, ch / wh);
            return { key: String(w.id), width: ww * k, height: wh * k };
        });
        const lines = [];
        for (let r = 0; r < rows; ++r) {
            const line = pics.slice(r * columns, (r + 1) * columns);
            lines.push({ tiles: line, width: line.reduce((a, t) => a + t.width, 0) + gap * (line.length - 1), height: Math.max(...line.map(t => t.height)) });
        }
        const gridWidth = Math.max(...lines.map(l => l.width));
        const gridHeight = lines.reduce((a, l) => a + l.height + caption, 0) + gap * (rows - 1);
        const area = pics.reduce((a, t) => a + t.width * t.height, 0);
        const shape = Math.abs(Math.log((gridWidth / gridHeight) / (width / height)));
        if (area > bestArea * 1.01 || (area >= bestArea * 0.99 && shape < bestShape)) {
            bestArea = Math.max(area, bestArea);
            bestShape = shape;
            let y = Math.max(0, (height - gridHeight) / 2);
            best = [];
            for (const l of lines) {
                let x = Math.max(0, (width - l.width) / 2);
                for (const t of l.tiles) {
                    best.push({ key: t.key, x: x, y: y + (l.height - t.height) / 2, width: t.width, height: t.height });
                    x += t.width + gap;
                }
                y += l.height + caption + gap;
            }
        }
    }
    return best;
}
// A window title without a trailing " - App" / " — App" part naming the
// app (the caption shows the app's icon next to it).
function shortTitle(title, appName) {
    const t = String(title || "").trim();
    const m = t.match(/^(.+?)\s+[-–—|]\s+([^-–—|]+)$/);
    const app = String(appName || "").toLowerCase();
    if (m && app && (m[2].toLowerCase().indexOf(app) >= 0 || app.indexOf(m[2].toLowerCase().trim()) >= 0))
        return m[1];
    return t || appName || "";
}

function sync(model, keys) {
    for (let i=model.count-1;i>=0;--i) if (keys.indexOf(model.get(i).key)<0) model.remove(i);
    for (let i=0;i<keys.length;++i) {
        if (i<model.count && model.get(i).key===keys[i]) continue;
        let j=i+1;while(j<model.count && model.get(j).key!==keys[i])++j;
        if(j<model.count)model.move(j,i,1);else model.insert(i,{key:keys[i]});
    }
}

// The windows a monitor's overview shows. selected: null = every window
// (minimized ones included, drawn dimmed), a workspace id, or "minimized".
// A minimized window belongs to the monitor it returns to and to no workspace.
function visible(windows, monitor, selected) {
    return windows.filter(w => w.monitor === monitor && (selected === null || (selected === "minimized" ? w.minimized === true : !w.minimized && w.workspaceId === selected)));
}
