pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import qs.Compositor
import qs.Core

// Session actions with run-mode safety:
//   overlay    – nothing (a dev shell must not end or power off the real session)
//   nested     – lock and logout act on the nested compositor only
//   production – everything
// Force quit kills an app's process; not from overlay mode, where the windows
// belong to the real session.
Singleton {
    readonly property bool canLock: RunMode.ownsSessionLock
    readonly property bool canLogout: !RunMode.isOverlay && Compositor.supports("exitSession")
    readonly property bool canPower: RunMode.isProduction
    readonly property bool canForceQuit: !RunMode.isOverlay

    // Set by the lock module; lock() is a no-op until it registers.
    property var lockHandler: null

    function lock() {
        if (canLock && lockHandler)
            lockHandler();
    }

    function logout() {
        if (canLogout)
            Compositor.exitSession(RunMode.isProduction);
    }

    function suspend() {
        if (canPower)
            Exec.run(["systemctl", "suspend"], null);
    }

    function reboot() {
        if (canPower)
            Exec.run(["systemctl", "reboot"], null);
    }

    function poweroff() {
        if (canPower)
            Exec.run(["systemctl", "poweroff"], null);
    }

    function forceQuit(pid: int) {
        if (canForceQuit && pid > 1 && pid !== Platform.processId)
            Exec.run(["kill", "-KILL", String(pid)], null);
    }

    function reason(): string {
        return RunMode.isOverlay ? I18n.tr("Disabled while Bifrost runs next to another shell") : RunMode.isNested ? I18n.tr("Only affects the nested session") : "";
    }
}
