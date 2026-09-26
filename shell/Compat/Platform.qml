pragma Singleton

import QtQuick
import Quickshell

// Thin wrapper over process-level Quickshell APIs so the rest of Bifrost does
// not depend on their exact names (they have moved between releases before,
// e.g. shellRoot → shellDir).
Singleton {
    readonly property string shellDir: Quickshell.shellDir
    readonly property int processId: Quickshell.processId

    // Resolves an icon name (or absolute path) to an image URL, from the
    // icon theme Bifrost uses (IconLookup, switches live), else Qt's lookup.
    function iconPath(name: string, fallback: string): string {
        if (!name)
            return fallback ? iconPath(fallback, "") : "";
        if (name.startsWith("/"))
            return "file://" + name;
        if (name.startsWith("file://") || name.startsWith("image://") && !name.startsWith("image://icon/"))
            return name;
        if (name.startsWith("image://icon/"))
            name = decodeURIComponent(name.substring(13).split("?")[0]);
        const found = IconLookup.lookup(name);
        if (found)
            return found;
        const fb = fallback ? IconLookup.lookup(fallback) : "";
        return fb && !Quickshell.hasThemeIcon(name) ? fb : Quickshell.iconPath(name, fallback || "application-x-executable");
    }

    function expandHome(path: string): string {
        return path.startsWith("~/") ? Quickshell.env("HOME") + path.substring(1) : path;
    }

    function env(name: string): string {
        return Quickshell.env(name) || "";
    }

    // For the shell's own helpers (Settings, systemctl, kill): they may end
    // with the shell.
    function execDetached(command: var) {
        Quickshell.execDetached(command);
    }

    // For what the user starts (apps, files, their own commands). Under
    // systemd (bifrost.service) a detached child still lives in the service's
    // cgroup and is killed with it on every restart; so each one gets its own
    // scope, named like other launchers do (app-<launcher>-<app id>-<random>,
    // in app.slice, the app id escaped as systemd-escape does), which also
    // lets portals and systemd-cgls tell apps apart.
    //   launch(["kitty"], { appId: "kitty", workingDirectory: "/tmp" })
    property bool scopes: false

    function launch(command: var, options: var) {
        const o = options || {};
        const cmd = launchCommand(command, o, scopes);
        Quickshell.execDetached(o.workingDirectory ? { command: cmd, workingDirectory: o.workingDirectory } : cmd);
    }

    function launchCommand(command: var, o: var, scoped: bool): var {
        let cmd = Array.from(command);
        if (scoped) {
            const id = escapeUnit(String(o.appId || cmd[0].split("/").pop()).replace(/\.desktop$/, ""));
            const rand = Math.floor(Math.random() * 0xffffffff).toString(16);
            cmd = ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--slice=app.slice", "--unit=app-bifrost-" + id + "-" + rand, "--"].concat(cmd);
        }
        return cmd;
    }

    function escapeUnit(text: string): string {
        let out = "";
        for (const c of text)
            out += /[A-Za-z0-9:_.]/.test(c) ? c : Array.from(unescape(encodeURIComponent(c))).map(b => "\\x" + b.charCodeAt(0).toString(16).padStart(2, "0")).join("");
        return out;
    }

    Component.onCompleted: {
        if (env("INVOCATION_ID"))
            Exec.run(["systemd-run", "--version"], code => scopes = code === 0, 3000);
    }

    // Quickshell doesn't handle Qt.quit(); end this instance with SIGTERM.
    function quit() {
        Quickshell.execDetached(["kill", String(Quickshell.processId)]);
    }

    // soft reload keeps windows where possible; hard recreates everything.
    function reload(hard: bool) {
        Quickshell.reload(hard);
    }
}
