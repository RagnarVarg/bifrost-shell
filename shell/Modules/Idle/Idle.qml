import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compositor
import qs.Core
import qs.Services

// What happens when nobody uses the computer (Settings → Power → When idle):
// the screens turn off, the session locks and the computer sleeps, each after
// its own time (0 = never), independently of the others. One Wayland idle
// monitor each (ext-idle-notify); apps that ask the system to stay awake (a
// playing video) postpone all three unless power.idle.respectInhibitors is off.
// Input turns the screens back on – here, and in the compositor itself
// (bifrostctl sets Hyprland's *_enables_dpms), so they wake even without us.
// Only where the shell owns the session (not next to another shell).
Scope {
    id: root

    readonly property var settings: Config.values.power.idle || ({})
    readonly property bool active: RunMode.ownsSessionLock
    readonly property bool respect: settings.respectInhibitors !== false
    property bool screensOff: false

    function minutes(key: string): int {
        return Number(settings[key]) || 0;
    }

    function setScreensOff(off: bool) {
        if (off === screensOff)
            return;

        screensOff = off;
        console.info("[bifrost] idle: screens", off ? "off" : "on");
        Compositor.setDisplaysPower(!off);

        if (!off)
            wakeRetry.restart();
    }

    Timer {
        id: wakeRetry
        interval: 700
        repeat: false

        onTriggered: {
            console.info("[bifrost] idle: retrying display wake");
            Compositor.setDisplaysPower(true);
        }
    }

    // Quickshell's IdleMonitor keeps the timeout it started with, so a
    // changed setting makes a new monitor (a new model value).
    component Watch: Scope {
        id: watch

        property bool enabled: false
        property int minutes: 0
        property bool respect: true
        property bool isIdle: false

        Variants {
            model: watch.enabled && watch.minutes > 0 ? [{ timeout: watch.minutes * 60, respect: watch.respect }] : []

            IdleMonitor {
                required property var modelData

                timeout: modelData.timeout
                respectInhibitors: modelData.respect
                onIsIdleChanged: watch.isIdle = isIdle
                Component.onDestruction: watch.isIdle = false
            }
        }
    }

    Watch {
        enabled: root.active && Compositor.supports("displayPower")
        minutes: root.minutes("screenOffMinutes")
        respect: root.respect
        onIsIdleChanged: root.setScreensOff(isIdle)
    }

    Watch {
        enabled: root.active && Session.canLock
        minutes: root.minutes("lockMinutes")
        respect: root.respect
        onIsIdleChanged: if (isIdle) {
            console.info("[bifrost] idle: locking");
            Session.lock();
        }
    }

    Watch {
        enabled: root.active && Session.canPower
        minutes: root.minutes("suspendMinutes")
        respect: root.respect
        onIsIdleChanged: if (isIdle) {
            console.info("[bifrost] idle: sleeping");
            Session.suspend();
        }
    }
}
