import QtQuick
import Quickshell
import Quickshell.Io
import qs.Compositor
import qs.Core
import qs.Components.Popup
import qs.Services

// IPC for shell panels. Example: qs ipc -p <repo>/shell call launcher toggle
// (bind these to keys in a compositor config when Bifrost becomes the shell).
Scope {
    IpcHandler {
        target: "overview"
        function toggle(): void { ShellState.toggleOverview(); }
        function open(): void { ShellState.openOverview(); }
        function close(): void { ShellState.overviewOpen=false; }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            ShellState.toggleLauncher("");
        }

        function open(): void {
            ShellState.openLauncher("");
        }

        function close(): void {
            ShellState.launcherOpen = false;
        }

        // Opens the launcher with a query (scripting/testing).
        function search(query: string): void {
            ShellState.launcherQuery = query;
            ShellState.openLauncher("");
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            ShellState.toggleControlCenter("", null);
        }

        function close(): void {
            ShellState.controlCenterOpen = false;
        }

        // Opens the control center with a detail view, e.g. "bluetooth".
        function openDetail(detail: string): void {
            if (!ShellState.controlCenterOpen)
                ShellState.toggleControlCenter("", null);
            ShellState.controlCenterDetail = detail;
        }
    }

    IpcHandler {
        target: "audio"

        function increment(): void {
            Audio.adjust(Config.values.controlCenter.volumeStep / 100);
        }

        function decrement(): void {
            Audio.adjust(-Config.values.controlCenter.volumeStep / 100);
        }

        function mute(): void {
            Audio.toggleMute();
        }

        function micMute(): void {
            Audio.toggleMicMute();
        }
    }

    IpcHandler {
        target: "brightness"

        function increment(): void {
            Brightness.adjust(0.05);
        }

        function decrement(): void {
            Brightness.adjust(-0.05);
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            ShellState.toggleNotificationCenter("", null);
        }

        function clear(): void {
            Notify.clearAll();
        }

        function dnd(on: bool): void {
            Notify.setDnd(on);
        }

        function status(): string {
            return JSON.stringify({
                server: Notify.active,
                dnd: Notify.dnd,
                popups: Notify.popups.length,
                history: Notify.history.length,
                unread: Notify.unread,
                persisted: (Store.get("notifications") || []).length
            });
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            Session.lock();
        }

        function isLocked(): bool {
            return ShellState.locked;
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            ShellState.togglePowerMenu("");
        }
    }

    // Window-manager actions through the compositor facade (keybinds, tests).
    IpcHandler {
        target: "wm"

        function focusWorkspace(id: int): bool {
            return Compositor.focusWorkspace(id);
        }

        function focusWindow(id: string): bool {
            return Compositor.focusWindow(id);
        }

        function moveWindowToWorkspace(id: string, workspace: int): bool {
            return Compositor.moveWindowToWorkspace(id, workspace);
        }

        function closeWindow(id: string): bool {
            return Compositor.closeWindow(id);
        }

        function fullscreen(id: string): bool {
            return Compositor.setFullscreen(id, "fullscreen", "toggle");
        }

        function floating(id: string): bool {
            return Compositor.setFloating(id, "toggle");
        }

        function minimize(id: string): bool {
            return Compositor.minimizeWindow(id);
        }

        function restore(id: string): bool {
            return Compositor.restoreWindow(id);
        }

        // Keybinds: the focused window, and the most recently minimized one.
        function minimizeActive(): bool {
            return Compositor.activeWindow !== null && Compositor.minimizeWindow(Compositor.activeWindow.id);
        }

        function restoreLast(): bool {
            const last = Compositor.windows.filter(w => w.minimized).sort((a, b) => b.minimizedAt - a.minimizedAt)[0];
            return !!last && Compositor.restoreWindow(last.id);
        }
    }

    IpcHandler {
        target: "dock"

        // Panels grown out of the dock (Placement): what is open and its
        // hover state (hover tests).
        function status(): string {
            return JSON.stringify(Placement.dockHosts.map(h => h.hoverState));
        }
    }

    IpcHandler {
        target: "media"

        function playPause(): void {
            Media.togglePlaying();
            if (Media.available && Media.canToggle)
                ShellState.showMediaOsd("toggle");
        }

        function next(): void {
            Media.next();
            if (Media.available && Media.canNext)
                ShellState.showMediaOsd("next");
        }

        function previous(): void {
            Media.previous();
            if (Media.available && Media.canPrevious)
                ShellState.showMediaOsd("previous");
        }

        function stop(): void {
            Media.stop();
            if (Media.available && Media.canControl)
                ShellState.showMediaOsd("stop");
        }
    }

    IpcHandler {
        target: "bar"

        // Toggles a bar menu: network | vpn | bluetooth | audio | display | clock | system.
        // system:about | system:recent | system:forceQuit open the system menu on that page.
        function statusMenu(menu: string): void {
            ShellState.statusMenuRequested(ShellState.focusedScreen(), menu);
        }

        function status(): string {
            return JSON.stringify(ShellState.barWindows.map(w => Object.assign({ screen: w.modelData.name }, w.hoverState)));
        }

        // Where each widget is on its monitor, and what is open (hover tests).
        function widgets(): string {
            return JSON.stringify({
                bars: ShellState.barWindows.map(w => ({ screen: w.modelData.name, widgets: w.widgetRects() })),
                menu: PopupGroup.current !== null,
                menuFrom: (() => {
                        let a = PopupGroup.current ? PopupGroup.current.anchorItem : null;
                        while (a && a.entry === undefined)
                            a = a.parent;
                        return a ? a.entry.id : null;
                    })(),
                controlCenter: ShellState.controlCenterOpen,
                notificationCenter: ShellState.notificationCenterOpen
            });
        }
    }

    // Shows the OSD without changing anything (for testing the look).
    IpcHandler {
        target: "osd"

        // kind: volume | mic | brightness | media (the playing track).
        function preview(kind: string, percent: int): void {
            if (kind === "media")
                ShellState.showMediaOsd("toggle");
            else
                ShellState.showOsd(kind, percent / 100, false);
        }
    }
}
