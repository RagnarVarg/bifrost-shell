pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Core

// Notification daemon (org.freedesktop.Notifications). The server only exists
// when the run mode owns notifications (nested/production) and the user
// enabled it; in overlay mode the production shell keeps the D-Bus name.
//
// popups:  notifications currently shown as popups (newest first)
// history: everything received this session, newest first (capped)
Singleton {
    id: root

    readonly property bool active: server !== null
    readonly property bool dnd: Config.values.notifications.doNotDisturb === true
    property var server: null
    property var popups: []
    property var history: []
    property int unread: 0

    function normalise(n) {
        return {
            id: n.id,
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            image: n.image || "",
            critical: n.urgency === NotificationUrgency.Critical,
            timeout: n.expireTimeout,
            time: new Date(),
            actions: n.actions ? n.actions.map(a => ({ id: a.identifier, text: a.text, invoke: () => a.invoke() })) : [],
            source: n
        };
    }

    // History survives restarts via State (without live sender objects).
    function persist() {
        Store.set("notifications", history.slice(0, Config.values.notifications.historyLimit).map(h => ({
                        id: h.id,
                        appName: h.appName,
                        appIcon: h.appIcon,
                        summary: h.summary,
                        body: h.body,
                        image: h.image.startsWith("image://qsimage") ? "" : h.image,
                        critical: h.critical,
                        time: h.time.getTime()
                    })));
    }

    function restore() {
        const saved = Store.get("notifications") || [];
        history = saved.map(h => Object.assign({}, h, {
                    time: new Date(h.time),
                    timeout: 0,
                    actions: [],
                    source: null
                }));
    }

    onHistoryChanged: if (active)
        persist()

    function receive(n) {
        n.tracked = true;
        const item = normalise(n);
        n.closed.connect(() => root.forget(item.id));
        history = [item].concat(history.filter(h => h.id !== item.id)).slice(0, Config.values.notifications.historyLimit);
        unread++;
        if (!dnd || item.critical)
            popups = [item].concat(popups.filter(p => p.id !== item.id)).slice(0, Config.values.notifications.maxVisible);
    }

    // Popup timed out or was clicked away: keep it in history.
    function hidePopup(id: int) {
        popups = popups.filter(p => p.id !== id);
    }

    // Dismissed by the user: tell the sender and drop it everywhere.
    function dismiss(id: int) {
        const item = history.find(h => h.id === id);
        if (item && item.source)
            item.source.dismiss();
        forget(id);
    }

    function forget(id) {
        popups = popups.filter(p => p.id !== id);
        history = history.filter(h => h.id !== id);
    }

    function clearAll() {
        for (const h of history)
            if (h.source)
                h.source.dismiss();
        history = [];
        popups = [];
        unread = 0;
    }

    function markRead() {
        unread = 0;
    }

    function setDnd(on: bool) {
        Config.set("notifications.doNotDisturb", on);
        if (on)
            popups = popups.filter(p => p.critical);
    }

    Component {
        id: serverComponent

        NotificationServer {
            keepOnReload: true
            bodySupported: true
            bodyMarkupSupported: false
            actionsSupported: true
            imageSupported: true
            persistenceSupported: true
            onNotification: n => root.receive(n)
        }
    }

    Component.onCompleted: {
        if (RunMode.ownsNotifications && Config.values.notifications.server) {
            server = serverComponent.createObject(root);
            restore();
        }
        console.info("[bifrost] notifications:", server ? "server active" : "not owned (" + RunMode.mode + " mode)");
    }
}
