import QtQuick
import Quickshell
import Quickshell.Io
import qs.Compat
import qs.Compositor

// `qs ipc -p <shell> call bifrost <fn> …` — scripting and Settings → shell.
IpcHandler {
    target: "bifrost"

    function ping(): string {
        return "pong " + RunMode.mode;
    }

    function status(): string {
        return JSON.stringify({
            mode: RunMode.mode,
            compositor: Compositor.kind,
            compositorVersion: Compositor.version,
            compositorSupported: Compositor.supported,
            configFile: Paths.configFile,
            preset: Config.preset,
            revision: Config.revision,
            theme: Theme.chainIds,
            variant: Theme.variant,
            configIssues: Config.issues,
            themeIssues: Theme.issues,
            schemaErrors: Schema.errors,
            pendingReload: ApplyState.pendingReload,
            pendingRestart: ApplyState.pendingRestart
        });
    }

    // Normalised compositor state, as the UI sees it.
    function compositor(): string {
        return JSON.stringify({
            kind: Compositor.kind,
            capabilities: Compositor.capabilities,
            activeWorkspace: Compositor.activeWorkspace,
            activeWindow: Compositor.activeWindow,
            monitors: Compositor.monitors,
            workspaces: Compositor.workspaces,
            windowCount: Compositor.windows.length
        });
    }

    function get(key: string): string {
        return JSON.stringify(Config.get(key));
    }

    // value is JSON ("true", "42", "\"text\"", "null"); bare words are strings.
    // Note: the `qs ipc` CLI itself parses arguments shaped like [a,b] into
    // several arguments, so pass JSON arrays with a leading space: ' ["a","b"]'.
    // tools/bifrostctl has no such quirk.
    function set(key: string, value: string): string {
        let v;
        try {
            v = JSON.parse(value);
        } catch (e) {
            v = value;
        }
        return Config.set(key, v) || "ok";
    }

    function reset(key: string): string {
        return Config.reset(key) || "ok";
    }

    function token(path: string): string {
        let node = Theme.tokens;
        for (const part of path.split("."))
            node = node ? node[part] : undefined;
        return JSON.stringify(node);
    }

    // Opens Bifrost Settings (separate process) at a section or setting key.
    function openSettings(page: string): void {
        Launch.openSettings(page);
    }

    function reload(): void {
        Config.flush();
        Platform.reload(false);
    }

    // Restarts the shell process. Only possible when a service manager owns
    // it (systemd sets INVOCATION_ID); returns "unsupported" otherwise.
    function restart(): string {
        if (!Platform.env("INVOCATION_ID"))
            return "unsupported";
        Config.flush();
        Platform.execDetached(["systemctl", "--user", "restart", "bifrost.service"]);
        return "ok";
    }
}
