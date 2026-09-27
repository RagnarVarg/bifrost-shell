pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Today's events from the system calendars (Evolution Data Server: GNOME
// Calendar, Evolution, GNOME Online Accounts) through tools/calendar_events.py.
// Read only. Fetches only while retained (the clock menu is open): when it
// opens, every five minutes while open, and when the day changes.
//   status: "loading" | "ok" | "unavailable" (reason says why)
Singleton {
    id: root

    property string status: "loading"
    property string reason: ""
    property var calendars: []
    property var events: []            // [{ title, start, end (ms), allDay, calendar, location }]
    property var loadedDay: ""
    property int users: 0
    property bool busy: false

    // The event that is on now, else the next one today (not all-day).
    readonly property var next: {
        const now = Time.now.getTime();
        return events.find(e => !e.allDay && e.end > now) || null;
    }

    function dayKey(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }

    function retain() {
        users++;
        if (users === 1)
            refresh();
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    function refresh() {
        if (busy)
            return;
        busy = true;
        const day = dayKey(Time.now);
        Exec.run(["python3", Paths.repoDir + "/tools/calendar_events.py"], (code, out) => {
            busy = false;
            let data = null;
            try {
                data = JSON.parse(out);
            } catch (e) {
                data = { status: "unavailable", reason: "The calendar could not be read" };
            }
            status = data.status === "ok" ? "ok" : "unavailable";
            reason = data.reason || "";
            calendars = data.calendars || [];
            events = data.events || [];
            loadedDay = day;
        }, 20000, root);
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.users > 0
        onTriggered: root.refresh()
    }

    Connections {
        target: Time

        function onNowChanged() {
            if (root.users > 0 && root.loadedDay !== "" && root.dayKey(Time.now) !== root.loadedDay)
                root.refresh();
        }
    }
}
