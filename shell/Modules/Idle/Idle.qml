import QtQuick
import Quickshell
import Quickshell.Io
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
//
// Every step is logged with "[bifrost] idle:" (journalctl --user -u bifrost -g idle).
Scope {
    id: root

    readonly property var settings: Config.values.power.idle || ({})
    readonly property bool active: RunMode.ownsSessionLock
    readonly property bool respect: settings.respectInhibitors !== false
    property bool screensOff: false

    // Wake sequence. It checks before it acts: the compositor has usually
    // woken the screens itself on the same input, and a second "dpms on" is a
    // needless modeset. Screens still off get "dpms on" again after each delay
    // (NVIDIA can leave a DisplayPort output off on the first request); if
    // that is not enough, one full off → on cycle. A new screen-off or wake
    // abandons a sequence still running (wakeRun).
    readonly property var wakeDelays: [300, 800, 1500, 3000]
    property int wakeRun: 0
    property int wakeStep: 0
    property bool wakeCycled: false
    property double wokeAt: 0

    function minutes(key: string): int {
        return Number(settings[key]) || 0;
    }

    function describe(list): string {
        if (!list)
            return "state unknown";
        if (list.length === 0)
            return "no display connected";
        return list.map(d => d.name + " " + (!d.enabled ? "disabled" : d.on ? "on" : "off")).join(", ");
    }

    // reason: what turned them off/on, for the log ("idle"/"input" by default).
    function setScreensOff(off: bool, reason: string) {
        if (off === screensOff)
            return;

        screensOff = off;
        wakeRun++;
        wakeTimer.stop();
        cycleTimer.stop();
        Brightness.paused = off;

        if (off) {
            console.info("[bifrost] idle: turning screens off (" + (reason || "idle for " + minutes("screenOffMinutes") + " min") + ")");
            Compositor.setDisplaysPower(false, ok => {
                if (ok)
                    offCheck.restart();
            });
        } else {
            beginWake(reason || "input");
        }
    }

    function beginWake(reason: string) {
        wakeRun++;
        wakeStep = 0;
        wakeCycled = false;
        // A hotplug re-check keeps the original wake time (and its window).
        if (reason !== "monitor hotplug" || wokeAt === 0)
            wokeAt = Date.now();
        cycleTimer.stop();
        console.info("[bifrost] idle: waking screens (" + reason + ")");
        // A moment for the compositor's own wake on the same input.
        wakeTimer.interval = 150;
        wakeTimer.restart();
    }

    function checkWake() {
        const run = wakeRun;
        Compositor.queryDisplaysPower(list => {
            if (run !== root.wakeRun || root.screensOff)
                return;
            const ms = Date.now() - root.wokeAt;
            const off = (list || []).filter(d => d.enabled && !d.on).map(d => d.name);
            const connected = !!list && list.length > 0;

            if (connected && off.length === 0) {
                console.info("[bifrost] idle: screens on after", ms, "ms –", root.describe(list),
                    root.wakeStep === 0 ? "(already awake, nothing sent)" : "(" + root.wakeStep + "× dpms on" + (root.wakeCycled ? ", off/on cycle" : "") + ")");
                return;
            }

            if (root.wakeStep < root.wakeDelays.length) {
                root.wakeStep++;
                if (connected) {
                    console.info("[bifrost] idle: still off after", ms, "ms –", off.join(", "), "– dpms on, attempt", root.wakeStep, "of", root.wakeDelays.length);
                    Compositor.setDisplaysPower(true, null);
                } else {
                    // A monitor in deep standby can drop its DisplayPort link;
                    // it comes back as a hotplug (see the Connections below).
                    console.warn("[bifrost] idle:", root.describe(list), "after", ms, "ms – waiting for the monitor");
                }
                wakeTimer.interval = root.wakeDelays[root.wakeStep - 1];
                wakeTimer.restart();
                return;
            }

            if (connected && !root.wakeCycled) {
                root.wakeCycled = true;
                console.warn("[bifrost] idle: still off after", root.wakeStep, "attempts –", off.join(", "), "– cycling dpms off → on");
                Compositor.setDisplaysPower(false, () => {
                    if (run === root.wakeRun)
                        cycleTimer.restart();
                });
                return;
            }

            console.error("[bifrost] idle: screens did not wake after", ms, "ms –", root.describe(list),
                "– please report; input or a monitor hotplug checks again");
        });
    }

    Timer {
        id: wakeTimer
        repeat: false
        onTriggered: root.checkWake()
    }

    Timer {
        id: cycleTimer
        interval: 600
        repeat: false
        onTriggered: {
            console.info("[bifrost] idle: dpms on after the off/on cycle");
            Compositor.setDisplaysPower(true, null);
            wakeTimer.interval = 1500;
            wakeTimer.restart();
        }
    }

    // Confirms (in the log) what the compositor reports after a screen-off.
    Timer {
        id: offCheck
        interval: 1500
        repeat: false
        onTriggered: Compositor.queryDisplaysPower(list => {
            if (!root.screensOff)
                return;
            const stillOn = (list || []).filter(d => d.enabled && d.on).map(d => d.name);
            if (stillOn.length)
                console.warn("[bifrost] idle: screens off requested but", stillOn.join(", "), "still reports on");
            else
                console.info("[bifrost] idle: screens off –", root.describe(list));
        })
    }

    // A monitor that dropped off in standby reconnects shortly after the
    // wake: check its power once more (only reads unless one is still off).
    Connections {
        target: Compositor

        function onEvent(name, data) {
            if (name !== "monitors" || root.screensOff || root.wokeAt === 0 || Date.now() - root.wokeAt > 60000)
                return;
            console.info("[bifrost] idle: displays changed after the wake – checking power again");
            root.beginWake("monitor hotplug");
        }
    }

    // bifrost-ipc idle status | wake | testScreenOff <seconds>
    IpcHandler {
        target: "idle"

        function status(): string {
            return JSON.stringify({
                active: root.active,
                screensOff: root.screensOff,
                wakeStep: root.wakeStep,
                wakeCycled: root.wakeCycled,
                screenOffMinutes: root.minutes("screenOffMinutes"),
                lockMinutes: root.minutes("lockMinutes"),
                suspendMinutes: root.minutes("suspendMinutes")
            });
        }

        function wake(): void {
            if (root.screensOff)
                root.setScreensOff(false, "ipc");
            else
                root.beginWake("ipc");
        }

        // The whole off → wake chain without waiting for the timeout: screens
        // off now, woken by the same routine after `seconds` (2–60), also when
        // no input arrives.
        function testScreenOff(seconds: int): string {
            if (!root.active || !Compositor.supports("displayPower"))
                return "unavailable in this run mode";
            testWake.interval = Math.max(2, Math.min(60, seconds || 5)) * 1000;
            console.info("[bifrost] idle: test – screens off for", testWake.interval / 1000, "s");
            root.setScreensOff(true, "test");
            testWake.restart();
            return "screens off for " + testWake.interval / 1000 + " s";
        }
    }

    Timer {
        id: testWake
        repeat: false
        onTriggered: root.setScreensOff(false, "test timer")
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
        onIsIdleChanged: root.setScreensOff(isIdle, "")
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
