import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Core
import qs.Modules
import qs.Services

// Session lock (ext-session-lock) with PAM authentication. Only active when
// the run mode owns the session lock (nested/production); never in overlay.
Scope {
    id: lock

    property bool busy: false
    property bool failed: false
    property string message: ""
    property string pending: ""

    function submit(password: string) {
        if (busy || password === "")
            return;
        pending = password;
        busy = true;
        failed = false;
        message = "";
        pam.start();
    }

    Component.onCompleted: Session.lockHandler = () => {
        if (RunMode.ownsSessionLock)
            ShellState.locked = true;
    }

    PamContext {
        id: pam

        config: Config.values.lock.pamService
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(lock.pending);
                lock.pending = "";
            }
        }
        onCompleted: result => {
            lock.busy = false;
            if (result === PamResult.Success) {
                lock.message = "";
                ShellState.locked = false;
            } else {
                lock.failed = true;
                lock.message = result === PamResult.MaxTries ? I18n.tr("Too many attempts") : I18n.tr("Wrong password");
            }
        }
        onError: e => {
            lock.busy = false;
            lock.failed = true;
            lock.message = "Autentiseringen misslyckades (" + PamError.toString(e) + ")";
        }
    }

    WlSessionLock {
        locked: ShellState.locked && RunMode.ownsSessionLock

        WlSessionLockSurface {
            color: Theme.palette.void

            LockSurface {
                anchors.fill: parent
                auth: lock
            }
        }
    }
}
