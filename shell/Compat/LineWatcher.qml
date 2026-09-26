import QtQuick
import Quickshell.Io

// Runs a long-lived command and emits every stdout line (e.g. `gsettings
// monitor`, `nmcli monitor`). Restarts it with a back-off if it exits while
// `active`. Stops the process when inactive or destroyed, and — through the
// kernel's parent-death signal (setpriv) — when the shell itself exits
// without running destructors (selftest, a killed instance); otherwise
// every such exit left a `gsettings monitor` behind.
Item {
    id: root

    property var command: []
    property bool active: true
    property int restartMs: 2000
    property bool writable: false     // write() sends lines to its stdin

    signal line(string text)
    signal started

    function write(text: string) {
        if (proc.running)
            proc.write(text + "\n");
    }

    visible: false

    Process {
        id: proc

        command: root.command.length > 0 ? ["setpriv", "--pdeathsig", "TERM", "--"].concat(root.command) : []
        running: root.active && root.command.length > 0
        stdinEnabled: root.writable
        onStarted: root.started()
        stdout: SplitParser {
            onRead: data => root.line(data)
        }
        onExited: {
            if (root.active)
                restart.restart();
        }
    }

    Timer {
        id: restart

        interval: root.restartMs
        onTriggered: {
            if (root.active && !proc.running)
                proc.running = true;
        }
    }
}
