import QtQuick

// Contract every compositor backend implements (see docs/COMPOSITOR.md).
// Defaults are "unsupported" no-ops, so a backend only overrides what its
// compositor can do. UI code never talks to a backend directly; it uses the
// `Compositor` facade and checks `capabilities` rather than compositor names.
//
// Normalised shapes (plain JS objects):
//   workspace { id, name, index, monitor, active, focused, urgent, windowCount, special }
//   window    { id, appId, title, workspaceId, workspaceName, monitor, focused, floating,
//               fullscreen, minimized, minimizedAt, x, y, width, height }
//               (global layout coordinates). A minimized window is still open and
//               listed; `monitor` is the one it returns to (Minimize.js).
//   monitor   { name, x, y, width, height, scale, refreshRate, focused, activeWorkspaceId }
QtObject {
    id: backend

    property string kind: "none"
    property string displayName: "Unknown compositor"
    property string version: ""
    property bool ready: true
    property bool supported: false

    // Settings and UI branch on these, never on `kind`.
    property var capabilities: ({
            workspaces: false,
            namedWorkspaces: false,
            specialWorkspaces: false,
            scrollingLayout: false,
            windowList: false,
            focusWorkspace: false,
            focusWindow: false,
            moveWindow: false,
            closeWindow: false,
            fullscreen: false,
            floating: false,
            monitors: false,
            surfaceBlur: false,
            focusGrab: false,
            exitSession: false,
            cursorPosition: false,
            outputConfig: false,
            inputConfig: false,
            windowCapture: false,
            // minimizeWindow/restoreWindow work, and windows report `minimized`
            // from compositor state (not geometry).
            minimizeWindow: false,
            restoreWindow: false,
            minimizedWindowState: false,
            // minimize/restore can skip the compositor's own animation
            // (options.quiet), so Bifrost can draw the transition itself.
            minimizeTransition: false
        })

    property var workspaces: []
    property var windows: []
    property var monitors: []
    property var activeWorkspace: null
    property var activeWindow: null
    property var focusedMonitor: null

    // > 0 while someone needs up-to-date window geometry (intelligent hide);
    // backends may poll then, since tiling reflows don't always emit events.
    property int geometryWatchers: 0

    // Normalised compositor events, e.g. "workspace", "window-opened",
    // "window-closed", "focus", "monitors", "config-reloaded".
    signal event(string name, var data)

    // The normalised window with this id (backends may accept more than one
    // spelling of an id, e.g. Hyprland addresses with or without "0x").
    function findWindow(windowId) {
        const key = normaliseId(windowId);
        return windows.find(w => normaliseId(w.id) === key) || null;
    }

    function normaliseId(windowId) {
        return String(windowId);
    }

    function unsupported(what) {
        console.warn("[bifrost] " + kind + ": " + what + " is not supported");
        return false;
    }

    function focusWorkspace(workspaceId) {
        return unsupported("focusWorkspace");
    }

    function focusWindow(windowId) {
        return unsupported("focusWindow");
    }

    // Focuses (and raises, switching workspace if needed) the toplevel owned
    // by a process: how a single-instance app brings its own window forward.
    function focusProcessWindow(pid) {
        return unsupported("focusProcessWindow");
    }

    function moveWindowToWorkspace(windowId, workspaceId) {
        return unsupported("moveWindowToWorkspace");
    }

    function closeWindow(windowId) {
        return unsupported("closeWindow");
    }

    // Hides a window without closing it; it stays in `windows` with
    // minimized: true and must not take focus. options: { quiet } (see
    // capabilities.minimizeTransition).
    function minimizeWindow(windowId, options) {
        return unsupported("minimizeWindow");
    }

    // Brings a minimized window back (to `workspaceId` if given, else where
    // it was) and focuses it.
    function restoreWindow(windowId, workspaceId, options) {
        return unsupported("restoreWindow");
    }

    // mode: "fullscreen" | "maximized"; action: "toggle" | "set" | "unset"
    function setFullscreen(windowId, mode, action) {
        return unsupported("setFullscreen");
    }

    // action: "toggle" | "set" | "unset"
    function setFloating(windowId, action) {
        return unsupported("setFloating");
    }

    // Outputs with available modes: callback([{ name, description, enabled,
    // width, height, refreshRate, scale, x, y, vrr, bitdepth, cm (colour
    // preset: "srgb" | "hdr" | …),
    // modes: [{ width, height, refresh }] }]).
    function switchInputLayout(name,index,callback) { callback(false); }

    function queryInput(callback) { callback({devices:[], catalog:{layouts:[], options:[]}, error:"Input backend unavailable"}); }

    function queryOutputs(callback) {
        callback([]);
    }

    // Applies { name, width, height, refresh, x, y, scale, vrr, bitdepth, cm } at
    // runtime (not persisted by the backend).
    function applyOutput(output) {
        return unsupported("applyOutput");
    }

    // Global pointer position: callback({ x, y }) or callback(null).
    function queryCursor(callback) {
        callback(null);
    }

    // Ends the compositor session (logout).
    // The object a window capture (Compat/WindowCapture) takes for a window,
    // or null.
    function captureSource(windowId) {
        return null;
    }

    // endUnits: also stop the session's systemd units (production logout).
    function exitSession(endUnits) {
        return unsupported("exitSession");
    }

    // The main keyboard now: { capsLock, layouts: ["se", "us"], active: index, name }.
    function queryKeyboard(callback) {
        callback(null);
    }

    function nextKeyboardLayout() {
        return unsupported("keyboardLayouts");
    }

    // Turns every display's power on or off (DPMS); input wakes them too.
    function setDisplaysPower(on) {
        return unsupported("displayPower");
    }

    // While on, the compositor's own shortcuts are suspended so that a
    // focused window receives every key combination (recording a shortcut).
    function setKeyCapture(on) {
        return unsupported("keyCapture");
    }

    // Grab pointer/keyboard for popups: `onCleared` runs when the user clicks
    // outside `windows`. Returns an object with release(), or null when
    // unsupported (callers then close popups on Esc/leave instead).
    function createFocusGrab(windows, onCleared) {
        return null;
    }

    // Ask the compositor to render effects behind Bifrost's layer surfaces.
    // effects: { blur: bool }. Must never modify the user's config files.
    function ensureSurfaceEffects(namespacePrefix, effects) {
        return unsupported("ensureSurfaceEffects");
    }
}
