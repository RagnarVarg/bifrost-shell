.pragma library

// Minimized windows, compositor-neutral (a backend decides how a window is
// hidden; Hyprland: a Bifrost-owned special workspace). A backend reports a
// window as minimized from compositor state, never from geometry; what is
// kept here is only how to bring it back: a record per window id
//   { workspaceId, workspaceName, monitor, pinned, at }
// in a plain object (the store), persisted by the backend.

// The store with `win`'s return point added; `win` is a normalised window
// (before minimizing), `pinned` whether it was pinned (shown everywhere).
function remember(store, win, pinned, now) {
    const out = Object.assign({}, store);
    out[win.id] = {
        workspaceId: win.workspaceId,
        workspaceName: win.workspaceName || String(win.workspaceId),
        monitor: win.monitor || "",
        pinned: pinned === true,
        at: now
    };
    return out;
}

function forget(store, id) {
    if (!(id in store))
        return store;
    const out = Object.assign({}, store);
    delete out[id];
    return out;
}

// Drops records of windows that are open but no longer minimized (brought
// back some other way, e.g. a compositor keybind), unless younger than
// `graceMs` (the compositor may not have moved it yet). With `dropMissing`,
// also records of windows not open at all (closed); only pass it once the
// window list is known to be complete, or a shell start would forget every
// minimized window. Closing is otherwise handled per window (forget).
function prune(store, minimizedIds, openIds, now, graceMs, dropMissing) {
    const keep = {};
    let changed = false;
    for (const id in store) {
        const open = openIds.indexOf(id) >= 0;
        const keepIt = minimizedIds.indexOf(id) >= 0 || (open ? now - store[id].at < graceMs : !dropMissing);
        if (keepIt)
            keep[id] = store[id];
        else
            changed = true;
    }
    return changed ? keep : store;
}

// Where a minimized window goes back to: its workspace, on whichever
// monitor it now is. A regular workspace that no longer exists (compositors
// drop empty ones) is created again on the window's monitor if that is still
// there, else on the focused one (`create`). A user's special workspace that
// is gone is not recreated (that would show it): the workspace shown on the
// window's monitor, else on the focused monitor, instead. `workspaces` and
// `monitors` are normalised; returns { workspaceId, workspaceName, monitor,
// create } or null.
function restoreTarget(record, workspaces, monitors, focusedMonitor) {
    const fm = focusedMonitor || monitors.find(m => m.focused) || monitors[0] || null;
    if (record) {
        const ws = workspaces.find(w => w.id === record.workspaceId);
        if (ws)
            return { workspaceId: ws.id, workspaceName: ws.name, monitor: ws.monitor, create: false };
        const mon = monitors.find(m => m.name === record.monitor) || null;
        const special = String(record.workspaceName || "").startsWith("special:");
        if (!special && record.workspaceId !== null && record.workspaceId !== undefined)
            return { workspaceId: record.workspaceId, workspaceName: record.workspaceName || String(record.workspaceId), monitor: (mon || fm || {}).name || "", create: true };
        if (mon && mon.activeWorkspaceId !== null && mon.activeWorkspaceId !== undefined)
            return onMonitor(mon, workspaces);
    }
    return fm && fm.activeWorkspaceId !== null && fm.activeWorkspaceId !== undefined ? onMonitor(fm, workspaces) : null;
}

function onMonitor(mon, workspaces) {
    const ws = workspaces.find(w => w.id === mon.activeWorkspaceId);
    return { workspaceId: mon.activeWorkspaceId, workspaceName: ws ? ws.name : String(mon.activeWorkspaceId), monitor: mon.name, create: false };
}

// Marks normalised windows: minimized, when it was minimized, and for a
// minimized one the monitor it returns to (so per-monitor views list it
// there). `isMinimized(w)` comes from the backend's compositor state.
function annotate(windows, store, isMinimized) {
    return windows.map(w => {
        const min = isMinimized(w);
        const rec = min ? store[w.id] : null;
        return Object.assign(w, {
            minimized: min,
            minimizedAt: rec ? rec.at : 0,
            monitor: rec && rec.monitor ? rec.monitor : w.monitor
        });
    });
}

// What clicking an app in the dock does with its windows (activeId = the
// focused window): { id, restore } or null (nothing open).
//   - some shown: focus the first; when the app is focused, cycle through
//     its shown windows (minimized ones stay minimized)
//   - all minimized: restore the most recently minimized one
function dockActivation(windows, activeId) {
    const shown = windows.filter(w => !w.minimized);
    if (shown.length) {
        const cur = shown.findIndex(w => w.id === activeId);
        return { id: shown[(cur + 1) % shown.length].id, restore: false };
    }
    if (!windows.length)
        return null;
    const last = windows.slice().sort((a, b) => (b.minimizedAt || 0) - (a.minimizedAt || 0))[0];
    return { id: last.id, restore: true };
}
