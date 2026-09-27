pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Core

// Reminders made and checked off in the clock menu: a short list of
// { id, text, done } kept in Store (state.json), so they survive restarts.
Singleton {
    id: root

    readonly property var items: Store.data.reminders || []
    readonly property int doneCount: items.filter(r => r.done).length

    function save(list) {
        Store.set("reminders", list);
    }

    function add(text: string) {
        const t = text.trim();
        if (!t)
            return;
        // Unique even for two reminders made within the same millisecond.
        let id = String(Date.now());
        while (items.some(r => r.id === id))
            id += "x";
        save(items.concat([{ id: id, text: t, done: false }]));
    }

    function toggle(id: string) {
        save(items.map(r => r.id === id ? Object.assign({}, r, { done: !r.done }) : r));
    }

    function remove(id: string) {
        save(items.filter(r => r.id !== id));
    }

    function clearDone() {
        save(items.filter(r => !r.done));
    }
}
