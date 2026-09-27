pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import "Minimize.js" as Min

// The only compositor API that bar, dock, launcher, Settings etc. may use.
// Picks a backend at startup; everything compositor-specific (hyprctl, Niri
// IPC, layer rules, config languages) lives in that backend.
Singleton {
    id: root

    readonly property var known: ["hyprland", "niri"]
    readonly property string detected: {
        const forced = Platform.env("BIFROST_COMPOSITOR");
        if (forced)
            return forced;
        if (Platform.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return "hyprland";
        if (Platform.env("NIRI_SOCKET"))
            return "niri";
        return "none";
    }

    property CompositorBackend backend: null

    readonly property string kind: backend ? backend.kind : "none"
    readonly property string displayName: backend ? backend.displayName : ""
    readonly property string version: backend ? backend.version : ""
    readonly property bool ready: backend ? backend.ready : false
    readonly property bool supported: backend ? backend.supported : false
    readonly property var capabilities: backend ? backend.capabilities : ({})

    readonly property var workspaces: backend ? backend.workspaces : []
    readonly property var windows: backend ? backend.windows : []
    readonly property var monitors: backend ? backend.monitors : []
    readonly property var activeWorkspace: backend ? backend.activeWorkspace : null
    readonly property var activeWindow: backend ? backend.activeWindow : null
    readonly property var focusedMonitor: backend ? backend.focusedMonitor : null

    signal event(string name, var data)

    function supports(capability: string): bool {
        return capabilities[capability] === true;
    }

    function switchInputLayout(name: string, index: int, callback: var) {
        if (backend && supports("inputConfig")) backend.switchInputLayout(name,index,callback);
        else callback(false);
    }

    function queryInput(callback: var) {
        if (backend && supports("inputConfig")) backend.queryInput(callback);
        else callback({devices:[], catalog:{layouts:[], options:[]}, error:"Input backend unavailable"});
    }

    function queryOutputs(callback: var) {
        backend.queryOutputs(callback);
    }

    function applyOutput(output: var): bool {
        return backend.applyOutput(output);
    }

    // Asks where the pointer really is; callback(true/false/null) for whether
    // it is inside `rect` (monitor-local) on the monitor. null = unknown.
    function pointerIn(monitorName: string, rect: var, callback: var) {
        if (!backend || !supports("cursorPosition")) {
            callback(null);
            return;
        }
        backend.queryCursor(p => {
            const mon = monitors.find(m => m.name === monitorName);
            if (!p || !mon || !rect) {
                callback(null);
                return;
            }
            const x = p.x - mon.x, y = p.y - mon.y;
            callback(x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height);
        });
    }

    // Like pointerIn, for several rects at once: true if inside any of them.
    function pointerInAny(monitorName: string, rects: var, callback: var) {
        if (!backend || !supports("cursorPosition")) {
            callback(null);
            return;
        }
        backend.queryCursor(p => {
            const mon = monitors.find(m => m.name === monitorName);
            if (!p || !mon) {
                callback(null);
                return;
            }
            const x = p.x - mon.x, y = p.y - mon.y;
            callback(rects.some(r => r && x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height));
        });
    }

    function retainGeometry() {
        if (backend)
            backend.geometryWatchers++;
    }

    function releaseGeometry() {
        if (backend)
            backend.geometryWatchers = Math.max(0, backend.geometryWatchers - 1);
    }

    // Whether a window on the monitor's visible workspace overlaps `rect`
    // ({ x, y, width, height } in monitor-local coordinates). With
    // `tiledCovers`, any tiled or fullscreen window counts regardless of its
    // current geometry (for surfaces that reserve space while shown, where
    // tiled windows move out of the way).
    function windowsCover(monitorName: string, rect: var, tiledCovers: bool): bool {
        const mon = monitors.find(m => m.name === monitorName);
        if (!mon || !rect)
            return false;
        const rx = mon.x + rect.x, ry = mon.y + rect.y;
        return windows.some(w => {
            if (w.workspaceId === null || w.workspaceId !== mon.activeWorkspaceId)
                return false;
            if (tiledCovers && (!w.floating || w.fullscreen))
                return true;
            return w.width > 0 && w.x < rx + rect.width && w.x + w.width > rx && w.y < ry + rect.height && w.y + w.height > ry;
        });
    }

    // For Compat/WindowCapture: what to capture for a window (null = none).
    function captureSource(windowId: string): var {
        return backend && supports("windowCapture") ? backend.captureSource(windowId) : null;
    }

    function workspacesOn(monitorName: string): var {
        return workspaces.filter(w => w.monitor === monitorName);
    }

    function focusWorkspace(workspaceId: var): bool {
        return backend.focusWorkspace(workspaceId);
    }

    // Next/previous workspace on a monitor (delta ±1), within existing
    // non-special workspaces plus `minCount` persistent ones.
    function focusRelativeWorkspace(delta: int, monitorName: string, minCount: int): bool {
        const ids = workspaces.filter(w => !w.special && (!monitorName || w.monitor === monitorName)).map(w => w.id);
        for (let i = 1; i <= minCount; i++)
            if (ids.indexOf(i) < 0)
                ids.push(i);
        ids.sort((a, b) => a - b);
        const current = activeWorkspace ? activeWorkspace.id : ids[0];
        const idx = ids.indexOf(current);
        const next = ids[Math.max(0, Math.min(ids.length - 1, (idx < 0 ? 0 : idx) + (delta > 0 ? 1 : -1)))];
        return next !== current ? focusWorkspace(next) : false;
    }

    // Focusing a minimized window restores it (focusing it where it is
    // hidden would reveal the compositor's hiding place instead).
    function focusWindow(windowId: string): bool {
        if (isMinimized(windowId))
            return restoreWindow(windowId);
        return backend.focusWindow(windowId);
    }

    function isMinimized(windowId: string): bool {
        const w = backend ? backend.findWindow(windowId) : null;
        return !!w && w.minimized === true;
    }

    // Draws minimize/restore (a UI module registers itself here): every way
    // to minimize or restore comes through the two functions below, so they
    // all look the same. Contract:
    //   minimize(window, hide): calls hide() once, when it can cover the window
    //   restore(window, show):  calls show() once, when the window may appear
    // Only used when the backend can skip its own animation (no double one).
    property var windowTransitions: null

    function transitionsFor(windowId: string): var {
        return windowTransitions && supports("minimizeTransition") ? backend.findWindow(windowId) : null;
    }

    function minimizeWindow(windowId: string): bool {
        if (!backend || !supports("minimizeWindow"))
            return false;
        const w = transitionsFor(windowId);
        if (w && !w.minimized) {
            windowTransitions.minimize(w, () => backend.minimizeWindow(windowId, { quiet: true }));
            return true;
        }
        return backend.minimizeWindow(windowId);
    }

    // Back where it was (or to `workspaceId`), focused.
    function restoreWindow(windowId: string, workspaceId: var): bool {
        if (!backend || !supports("restoreWindow"))
            return false;
        const ws = workspaceId === undefined ? null : workspaceId;
        const w = transitionsFor(windowId);
        if (w && w.minimized) {
            windowTransitions.restore(w, () => backend.restoreWindow(windowId, ws, { quiet: true }));
            return true;
        }
        return backend.restoreWindow(windowId, ws);
    }

    // An app's windows, activated from the dock: focus (cycling while the
    // app is focused) its shown windows, or restore the most recently
    // minimized one when all are minimized (Minimize.dockActivation).
    function activateAppWindows(appWindows: var): bool {
        const a = Min.dockActivation(appWindows || [], activeWindow ? activeWindow.id : "");
        if (!a)
            return false;
        return a.restore ? restoreWindow(a.id) : focusWindow(a.id);
    }

    function toggleMinimized(windowId: string): bool {
        return isMinimized(windowId) ? restoreWindow(windowId) : minimizeWindow(windowId);
    }

    function focusProcessWindow(pid: int): bool {
        return backend.focusProcessWindow(pid);
    }

    // A minimized window moved to a workspace is restored there.
    function moveWindowToWorkspace(windowId: string, workspaceId: var): bool {
        if (isMinimized(windowId))
            return restoreWindow(windowId, workspaceId);
        return backend.moveWindowToWorkspace(windowId, workspaceId);
    }

    function closeWindow(windowId: string): bool {
        return backend.closeWindow(windowId);
    }

    function setFullscreen(windowId: string, mode: string, action: string): bool {
        return backend.setFullscreen(windowId, mode || "fullscreen", action || "toggle");
    }

    function setFloating(windowId: string, action: string): bool {
        return backend.setFloating(windowId, action || "toggle");
    }

    function exitSession(endUnits: bool): bool {
        return backend.exitSession(endUnits);
    }

    function queryKeyboard(callback: var) {
        backend.queryKeyboard(callback);
    }

    function nextKeyboardLayout(): bool {
        return backend.nextKeyboardLayout();
    }

    function setDisplaysPower(on: bool): bool {
        return backend.setDisplaysPower(on);
    }

    function setKeyCapture(on: bool): bool {
        return backend.setKeyCapture(on);
    }

    function createFocusGrab(windows: var, onCleared: var): var {
        return backend.createFocusGrab(windows, onCleared);
    }

    function ensureSurfaceEffects(namespacePrefix: string, effects: var): bool {
        return backend.ensureSurfaceEffects(namespacePrefix, effects);
    }

    Component {
        id: hyprlandComponent

        HyprlandBackend {}
    }

    Component {
        id: niriComponent

        NiriBackend {}
    }

    Component {
        id: noneComponent

        CompositorBackend {}
    }

    Connections {
        target: root.backend

        function onEvent(name, data) {
            root.event(name, data);
        }
    }

    Component.onCompleted: {
        const component = detected === "hyprland" ? hyprlandComponent : detected === "niri" ? niriComponent : noneComponent;
        backend = component.createObject(root);
        console.info("[bifrost] compositor:", detected);
    }
}
