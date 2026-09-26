pragma Singleton

import QtQuick
import Quickshell
import qs.Core

// Only one menu popup is open at a time: opening one closes the previous.
// Panels (control center etc.) close menus through closeAll(), and listen to
// `opened` to close themselves when a menu opens.
//
// Outside clicks close through the compositor focus grab, which also covers
// the bar. A click on the icon that opened the menu then arrives right after
// the grab closed it; justDismissed() lets the toggle ignore it so the same
// icon closes instead of reopening.
Singleton {
    id: group

    property var current: null
    property var lastDismissed: null
    property real lastDismissedAt: 0
    readonly property int reopenGuardMs: Theme.motion.duration.slow * 2

    signal opened(var popup)

    function register(popup) {
        if (current && current !== popup)
            current.close();
        current = popup;
        opened(popup);
    }

    function unregister(popup) {
        if (current === popup)
            current = null;
    }

    // `key` is the popup itself or a panel name.
    function noteDismissed(key) {
        lastDismissed = key;
        lastDismissedAt = Date.now();
    }

    function justDismissed(key): bool {
        return lastDismissed === key && Date.now() - lastDismissedAt < reopenGuardMs;
    }

    function closeAll() {
        if (current)
            current.close();
        current = null;
    }
}
