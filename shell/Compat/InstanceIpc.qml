pragma Singleton

import QtQuick
import Quickshell

// Calls IPC functions in other Bifrost Quickshell instances (shell, settings)
// through the `qs ipc` CLI, so no other code depends on its syntax.
Singleton {
    // entry: path of the instance's config (dir or .qml file)
    function call(entry: string, target: string, fn: string, args: var, callback: var) {
        Exec.run(["qs", "ipc", "-p", entry, "call", target, fn].concat(args || []), (code, out, err) => {
            if (callback)
                callback(code === 0, (out + err).trim());
        });
    }
}
