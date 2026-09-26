pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat

// Store: runtime state that should survive restarts (named Store because
// QtQuick already has a State type) but is not a setting
// (~/.config/bifrost/state.json): notification history, later recent apps.
// get(section) / set(section, value); writes are debounced.
Singleton {
    id: root

    property var data: ({})

    function get(section: string): var {
        return data[section];
    }

    function set(section: string, value: var) {
        const next = Object.assign({}, data);
        next[section] = value;
        data = next;
        writeTimer.restart();
    }

    Timer {
        id: writeTimer

        interval: 1000
        onTriggered: file.write(JSON.stringify(root.data, null, 1) + "\n")
    }

    WatchedFile {
        id: file

        path: Paths.stateFile
        watch: false
    }

    Component.onCompleted: {
        const text = file.readNow();
        try {
            data = text ? JSON.parse(text) : {};
        } catch (e) {
            console.warn("[bifrost] state.json unreadable, starting fresh:", e.message);
            data = {};
        }
    }
}
