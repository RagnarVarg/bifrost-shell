pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Compat
import "../Compat/Version.js" as V

// Hyprland backend. The only file in Bifrost that imports Quickshell.Hyprland,
// builds dispatcher syntax or calls hyprctl. Version and config-language
// differences are handled here and nowhere else.
//
// Hyprland >= 0.55 with a Lua config interprets `dispatch <x>` as Lua
// (`hl.dispatch(x)`), so the classic "workspace 3" syntax fails there.
// `Hyprland.usingLua` picks the dialect.
//
// Bifrost never writes Hyprland config files. Surface effects are runtime
// rules that vanish on `hyprctl reload`/reboot and are re-applied here after
// a config reload.
CompositorBackend {
    id: backend

    kind: "hyprland"
    displayName: "Hyprland"
    ready: probed
    supported: probed && V.atLeast(version, Deps.min("hyprland"))

    property bool probed: false
    readonly property bool usingLua: Hyprland.usingLua
    readonly property bool hasEval: probed && V.atLeast(version, Deps.feature("hyprland", "hyprctlEval"))

    // namespace prefix -> effects; re-applied after Hyprland reloads its config.
    property var surfaceEffects: ({})

    capabilities: ({
            inputConfig: supported && usingLua && hasEval,
            keyCapture: supported && usingLua && hasEval,
            displayPower: true,
            keyboardState: true,
            workspaces: true,
            namedWorkspaces: true,
            specialWorkspaces: true,
            scrollingLayout: false,
            windowList: true,
            focusWorkspace: true,
            focusWindow: true,
            moveWindow: true,
            closeWindow: true,
            fullscreen: true,
            floating: true,
            monitors: true,
            surfaceBlur: true,
            focusGrab: true,
            exitSession: true,
            cursorPosition: true,
            outputConfig: true,
            windowCapture: true
        })

    // Hyprland maps its windows to Wayland toplevels (hyprland-toplevel-mapping),
    // which Quickshell's screencopy can capture, also on hidden workspaces.
    function captureSource(windowId) {
        const t = Hyprland.toplevels.values.find(x => x.address === windowId);
        return t && t.wayland ? t.wayland : null;
    }

    // ── Actions ─────────────────────────────────────────────────────────
    // Lua forms verified: focus{workspace}, window.move{window=address:…}
    // (used by the user's own config). The rest follow the same pattern but
    // are unverified until tested in the nested session.
    function focusWorkspace(workspaceId) {
        return dispatch("hl.dsp.focus({ workspace = " + lua(String(workspaceId)) + " })", "workspace " + workspaceId);
    }

    function focusWindow(windowId) {
        return dispatch("hl.dsp.focus({ window = " + lua(target(windowId)) + " })", "focuswindow " + target(windowId));
    }

    function focusProcessWindow(pid) {
        const t = "pid:" + Number(pid);
        return dispatch("hl.dsp.focus({ window = " + lua(t) + " })", "focuswindow " + t);
    }

    function moveWindowToWorkspace(windowId, workspaceId) {
        return dispatch("hl.dsp.window.move({ workspace = " + lua(String(workspaceId)) + ", follow = false, window = " + lua(target(windowId)) + " })",
            "movetoworkspacesilent " + workspaceId + "," + target(windowId));
    }

    function closeWindow(windowId) {
        return dispatch("hl.dsp.window.close({ window = " + lua(target(windowId)) + " })", "closewindow " + target(windowId));
    }

    function setFullscreen(windowId, mode, action) {
        if (!usingLua) {
            // Legacy dispatcher only acts on the focused window.
            focusWindow(windowId);
            return dispatch("", "fullscreen " + (mode === "maximized" ? 1 : 0));
        }
        return dispatch("hl.dsp.window.fullscreen({ mode = " + lua(mode) + ", action = " + lua(action) + ", window = " + lua(target(windowId)) + " })", "");
    }

    function setFloating(windowId, action) {
        const legacy = action === "set" ? "setfloating " : action === "unset" ? "settiled " : "togglefloating ";
        return dispatch("hl.dsp.window.float({ action = " + lua(action) + ", window = " + lua(target(windowId)) + " })", legacy + target(windowId));
    }

    function switchInputLayout(name,index,callback) {
        if (!name || index < 0 || index > 3) { callback(false); return; }
        Exec.run(["hyprctl", "switchxkblayout", name, String(index)], (code,out) => callback(code === 0 && out.trim() === "ok"), 3000);
    }

    function queryInput(callback) {
        Exec.run(["python3", Platform.shellDir + "/../tools/bifrostctl", "input", "query", "--json"], (code, out) => {
            let data = null;
            try { data = JSON.parse(out); } catch (e) {}
            callback(code === 0 && data ? data : {devices:[], catalog:{layouts:[],options:[]}, error:"Input backend unavailable"});
        }, 15000);
    }

    function queryOutputs(callback) {
        Exec.run(["hyprctl", "monitors", "all", "-j"], (code, out) => {
            let list = [];
            try {
                list = JSON.parse(out).map(m => ({
                            name: m.name,
                            description: m.description || "",
                            enabled: !m.disabled,
                            width: m.width,
                            height: m.height,
                            refreshRate: m.refreshRate,
                            scale: m.scale,
                            x: m.x,
                            y: m.y,
                            vrr: m.vrr === true,
                            bitdepth: String(m.currentFormat || "").indexOf("2101010") >= 0 ? 10 : 8,
                            cm: m.colorManagementPreset || "srgb",
                            sdrBrightness: m.sdrBrightness === undefined ? 1 : Number(m.sdrBrightness),
                            modes: (m.availableModes || []).map(s => {
                                    const r = s.match(/(\d+)x(\d+)@([\d.]+)/);
                                    return r ? { width: Number(r[1]), height: Number(r[2]), refresh: Number(r[3]) } : null;
                                }).filter(x => x)
                        }));
            } catch (e) {
                console.error("[bifrost] cannot parse monitors:", e.message);
            }
            callback(list);
        }, 3000);
    }

    // Runtime only (hl.monitor via hyprctl eval); Bifrost persists the choice
    // in its own config and bifrost.lua, never in the user's Hyprland files.
    function applyOutput(o) {
        if (!usingLua || !hasEval)
            return unsupported("applyOutput without Lua config");
        const rule = {
            output: o.name,
            // Match bifrostctl.output_mode: force VRR-only rule changes to
            // reapply on Hyprland 0.56 without changing the physical mode.
            mode: o.width + "x" + o.height + "@" + (Number(o.refresh) + (o.vrr ? 0.01 : -0.01)).toFixed(5),
            position: o.x + "x" + o.y,
            scale: o.scale,
            vrr: o.vrr ? 1 : 0,
            bitdepth: o.bitdepth || 8
        };
        if (o.sdrBrightness !== undefined)
            rule.sdrbrightness = Math.max(0.5, Math.min(3, Number(o.sdrBrightness) || 1));
        if (o.cm)
            rule.cm = o.cm;
        if (o.cm === "hdr" || o.cm === "hdredid")
            rule.bitdepth = 10;
        Exec.run(["hyprctl", "eval", "local apply = dofile(" + lua(Platform.shellDir + "/Compat/MonitorApply.lua") + "); apply(" + luaTable(rule) + ")"], (code, out, err) => {
            if (code !== 0)
                console.error("[bifrost] applyOutput failed:", (out + err).trim());
        });
        return true;
    }

    function queryCursor(callback) {
        Exec.run(["hyprctl", "cursorpos", "-j"], (code, out) => {
            try {
                const p = JSON.parse(out);
                callback(code === 0 ? { x: p.x, y: p.y } : null);
            } catch (e) {
                callback(null);
            }
        }, 2000);
    }

    // With endUnits, bin/bifrost-logout stops graphical-session.target before
    // exiting: Hyprland 0.56 can segfault while exiting, and the target would
    // then outlive it (see the script). It runs as its own transient unit, as
    // stopping the target stops this shell. Plain dispatch if that fails.
    function exitSession(endUnits) {
        if (!endUnits)
            return dispatch("hl.dsp.exit()", "exit");
        const script = Platform.shellDir.replace(/\/shell\/?$/, "") + "/bin/bifrost-logout";
        Exec.run(["systemd-run", "--user", "--collect", "--quiet", "--unit=bifrost-logout",
                  "-E", "HYPRLAND_INSTANCE_SIGNATURE=" + Platform.env("HYPRLAND_INSTANCE_SIGNATURE"),
                  script, usingLua ? "hl.dsp.exit()" : "exit"], code => {
            if (code !== 0) {
                console.warn("[bifrost] logout: systemd-run failed (" + code + "), exiting the compositor directly");
                dispatch("hl.dsp.exit()", "exit");
            }
        }, 15000);
        return true;
    }

    function queryKeyboard(callback) {
        Exec.run(["hyprctl", "devices", "-j"], (code, out) => {
            let kb = null;
            try {
                const all = JSON.parse(out).keyboards || [];
                kb = all.find(k => k.main) || all[0] || null;
            } catch (e) {}
            callback(kb ? {
                capsLock: kb.capsLock === true,
                layouts: String(kb.layout || "").split(",").filter(s => s !== ""),
                active: kb.active_layout_index || 0,
                name: kb.active_keymap || ""
            } : null);
        }, 3000);
    }

    function nextKeyboardLayout() {
        Exec.run(["hyprctl", "switchxkblayout", "all", "next"], () => {}, 3000);
        return true;
    }

    function setDisplaysPower(on) {
        return dispatch("hl.dsp.dpms({ action = " + lua(on ? "on" : "off") + " })", "dpms " + (on ? "on" : "off"));
    }

    // An empty submap: no Hyprland shortcut fires, every key reaches the
    // focused window. Super+Escape leaves it should Settings not.
    // Defined once per Lua state (a reload clears both the submap and the flag).
    function setKeyCapture(on) {
        if (!usingLua || !hasEval)
            return unsupported("keyCapture");
        const define = 'if not _G.__bifrost_capture then hl.define_submap("bifrost-capture", function() hl.bind("SUPER + Escape", hl.dsp.submap("reset"), { description = "Stop recording a shortcut" }) end); _G.__bifrost_capture = true end; ';
        Exec.run(["hyprctl", "eval", (on ? define : "") + "hl.dispatch(hl.dsp.submap(" + lua(on ? "bifrost-capture" : "reset") + "))"], (code, out, err) => {
            if (code !== 0)
                console.error("[bifrost] key capture", on, "failed:", (out + err).trim());
        });
        return true;
    }

    function createFocusGrab(windows, onCleared) {
        const grab = focusGrabComponent.createObject(backend, { windows: windows });
        grab.cleared.connect(() => {
            if (onCleared)
                onCleared();
            grab.destroy();
        });
        grab.active = true;
        return {
            release: () => {
                if (grab) {
                    grab.active = false;
                    grab.destroy();
                }
            }
        };
    }

    property Component focusGrabComponent: Component {
        HyprlandFocusGrab {}
    }

    function ensureSurfaceEffects(namespacePrefix, effects) {
        const all = Object.assign({}, surfaceEffects);
        all[namespacePrefix] = effects;
        surfaceEffects = all;
        applySurfaceEffects(namespacePrefix, false);
        return true;
    }

    // ── Internals ───────────────────────────────────────────────────────
    function target(windowId) {
        return "address:" + (String(windowId).startsWith("0x") ? windowId : "0x" + windowId);
    }

    function lua(v) {
        return JSON.stringify(v);   // JSON string escaping is valid Lua
    }

    function luaTable(obj) {
        const parts = [];
        for (const k in obj) {
            const v = obj[k];
            const val = v && typeof v === "object" ? luaTable(v) : typeof v === "string" ? lua(v) : String(v);
            parts.push((/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[" + lua(k) + "]") + " = " + val);
        }
        return "{ " + parts.join(", ") + " }";
    }

    function dispatch(luaExpr, legacy) {
        const request = usingLua ? luaExpr : legacy;
        if (!request)
            return unsupported("dispatch in " + (usingLua ? "Lua" : "legacy") + " mode");
        Hyprland.dispatch(request);
        return true;
    }

    // Runtime layer rule, made idempotent by a Lua global so shell restarts
    // don't stack duplicates. After a config reload the rules are gone but the
    // Lua state may survive, so `force` re-adds regardless of the guard.
    function applySurfaceEffects(prefix, force) {
        const effects = surfaceEffects[prefix];
        if (!probed)
            return;   // applied once the version probe finishes
        if (!hasEval || !usingLua) {
            console.warn("[bifrost] surface effects need Hyprland >=", Deps.feature("hyprland", "hyprctlEval"), "with a Lua config; skipped");
            return;
        }
        const rule = {
            match: { namespace: "^" + prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ".*" },
            blur: effects.blur === true,
            ignore_alpha: effects.ignoreAlpha || 0.01,
            blur_popups: effects.blur === true
        };
        const guard = "_G.__bifrost_rules";
        const key = lua("surface:" + prefix + ":" + JSON.stringify(effects));
        const code = "if not " + guard + " then " + guard + " = {} end; " + (force ? guard + "[" + key + "] = nil; " : "") + "if not " + guard + "[" + key + "] then hl.layer_rule(" + luaTable(rule) + "); " + guard + "[" + key + "] = true end";
        Exec.run(["hyprctl", "eval", code], (exitCode, out, err) => {
            if (exitCode !== 0)
                console.error("[bifrost] layer rule for", prefix, "failed:", (out + err).trim());
        });
    }

    // ── State normalisation ─────────────────────────────────────────────
    // Quickshell fills monitor/workspace properties asynchronously after a
    // refresh*() call, so state is normalised twice: right away and after a
    // short settle delay (settleTimer). lastIpcObject is used as a fallback.
    function refresh() {
        const mons = Hyprland.monitors.values.map(m => {
            const ipc = m.lastIpcObject || {};
            const aw = m.activeWorkspace ? m.activeWorkspace.id : (ipc.activeWorkspace ? ipc.activeWorkspace.id : null);
            return {
                name: m.name,
                x: m.x || ipc.x || 0,
                y: m.y || ipc.y || 0,
                width: m.width || ipc.width || 0,
                height: m.height || ipc.height || 0,
                scale: m.scale || ipc.scale || 1,
                refreshRate: ipc.refreshRate || 0,
                focused: m.focused || ipc.focused === true,
                activeWorkspaceId: aw
            };
        });
        const activeIds = mons.map(m => m.activeWorkspaceId);
        const focusedMon = mons.find(m => m.focused) || (mons.length === 1 ? mons[0] : null);
        const focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : (focusedMon ? focusedMon.activeWorkspaceId : null);
        const ws = Hyprland.workspaces.values.map(w => ({
                    id: w.id,
                    name: w.name,
                    index: w.id,
                    monitor: w.monitor ? w.monitor.name : ((w.lastIpcObject || {}).monitor || ""),
                    active: activeIds.indexOf(w.id) >= 0,
                    focused: w.id === focusedId,
                    urgent: w.urgent,
                    windowCount: w.toplevels ? w.toplevels.values.length : ((w.lastIpcObject || {}).windows || 0),
                    special: w.id < 0
                })).sort((a, b) => a.id - b.id);
        const wins = Hyprland.toplevels.values.map(t => {
            const ipc = t.lastIpcObject || {};
            return {
                id: t.address,
                appId: ipc.class || (t.wayland ? t.wayland.appId : ""),
                title: t.title,
                pid: ipc.pid || 0,
                workspaceId: t.workspace ? t.workspace.id : null,
                monitor: t.monitor ? t.monitor.name : "",
                focused: t.activated,
                floating: ipc.floating === true,
                fullscreen: (ipc.fullscreen || 0) > 0,
                x: ipc.at ? ipc.at[0] : 0,
                y: ipc.at ? ipc.at[1] : 0,
                width: ipc.size ? ipc.size[0] : 0,
                height: ipc.size ? ipc.size[1] : 0
            };
        });
        workspaces = ws;
        windows = wins;
        monitors = mons;
        activeWorkspace = ws.find(w => w.focused) || null;
        activeWindow = wins.find(w => w.focused) || null;
        focusedMonitor = focusedMon;
    }

    readonly property var eventMap: ({
            workspacev2: "workspace",
            focusedmonv2: "focus",
            activewindowv2: "focus",
            openwindow: "window-opened",
            closewindow: "window-closed",
            movewindowv2: "window-moved",
            changefloatingmode: "window-changed",
            fullscreen: "window-changed",
            windowtitlev2: "window-changed",
            createworkspacev2: "workspace",
            destroyworkspacev2: "workspace",
            monitoraddedv2: "monitors",
            monitorremovedv2: "monitors",
            configreloaded: "config-reloaded"
        })

    property Timer refreshTimer: Timer {
        interval: 16
        onTriggered: {
            // Do not race Quickshell's initial status request. An update-only
            // refresh in flight makes its one create-capable refresh get skipped.
            if (Hyprland.monitors.values.length === 0)
                return;
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
            backend.refresh();
            backend.settleTimer.restart();
        }
    }

    // Tiling reflows and drags don't all emit events; poll geometry only
    // while intelligent hide (or similar) asks for it.
    property Timer geometryPoll: Timer {
        interval: 700
        repeat: true
        running: backend.geometryWatchers > 0 && Hyprland.monitors.values.length > 0
        onTriggered: {
            Hyprland.refreshToplevels();
            backend.settleTimer.restart();
        }
    }

    property Timer settleTimer: Timer {
        interval: 250
        onTriggered: backend.refresh()
    }

    // Diagnose missing initial tracking without blaming compositor readiness:
    // update-only QML refreshes can also race Quickshell's initial seed.
    property Timer trackingCheck: Timer {
        interval: 5000
        running: true
        onTriggered: {
            if (Hyprland.monitors.values.length > 0)
                return;
            Exec.run(["hyprctl", "monitors", "-j"], (code, out) => {
                if (code === 0 && out.indexOf("\"name\"") >= 0 && Hyprland.monitors.values.length === 0)
                    console.error("[bifrost] Quickshell's Hyprland IPC knows no monitors although Hyprland has some (initial tracking failed); restart the shell");
            }, 3000);
        }
    }

    property Connections focusWatch: Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            backend.refreshTimer.restart();
        }

        function onFocusedMonitorChanged() {
            backend.refreshTimer.restart();
        }

        function onActiveToplevelChanged() {
            backend.refreshTimer.restart();
        }
    }

    property Connections ipc: Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = backend.eventMap[event.name];
            if (!name)
                return;
            if (name === "config-reloaded")
                for (const prefix in backend.surfaceEffects)
                    backend.applySurfaceEffects(prefix, true);
            backend.refreshTimer.restart();
            backend.event(name, event.data);
        }
    }

    Component.onCompleted: {
        Exec.run(["hyprctl", "version", "-j"], (exitCode, out) => {
            try {
                const info = JSON.parse(out);
                version = info.version || String(info.tag || "").replace(/^v/, "");
            } catch (e) {
                console.error("[bifrost] cannot parse hyprctl version:", e.message);
            }
            probed = true;
            if (!supported)
                console.warn("[bifrost] Hyprland", version, "is older than the supported minimum", Deps.min("hyprland"));
            for (const prefix in surfaceEffects)
                applySurfaceEffects(prefix, false);
        });
        // HyprlandIpc first requests status, then seeds monitors/workspaces
        // with canCreate=true. Calling refresh* here uses canCreate=false and
        // can occupy requestingMonitors/requestingWorkspaces before that seed.
        // Let Quickshell finish initialization; subsequent updates use timers.
        refresh();
        settleTimer.restart();
    }
}
