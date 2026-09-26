//@ pragma AppId bifrost.greeter

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland
import qs.Compat
import qs.Compositor
import qs.Core
// Quickshell only registers qs.* modules reachable from the entry file.
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text
import qs.Greeter
import "Greeter/GreeterLogic.js" as Logic

// Bifrost's login screen (greetd). Started by greeter/bin/bifrost-greeter in
// its own minimal Hyprland, as the "greeter" user, with
//   BIFROST_CONFIG_DIR = <cache>/config   (your look, copied by `bifrostctl greeter sync`)
//   BIFROST_GREETER_CACHE = <cache>       (greeter.json: people, pictures, keyboard; state/)
// so Theme, glass and controls are exactly the shell's. Missing data only means
// defaults: no wallpaper → the lock screen's backdrop, no picture → initials.
//
// greetd dialogue (Quickshell.Services.Greetd): createSession(user) → the PAM
// questions come as authMessage; the typed password answers the first secret
// one, later ones (a second factor) are asked in the same field; authFailure =
// wrong password; readyToLaunch → launch(session). A marker file tells the
// launcher that login worked (otherwise it falls back to dms-greeter).
ShellRoot {
    id: greeter

    readonly property string cacheDir: Platform.env("BIFROST_GREETER_CACHE") || "/var/cache/bifrost-greeter"
    readonly property string runDir: Platform.env("BIFROST_GREETER_RUN") || ""
    readonly property string sessionsDir: Platform.env("BIFROST_GREETER_SESSIONS") || "/usr/share/wayland-sessions"

    property var meta: ({})
    property var memory: ({})
    property var passwdUsers: []
    readonly property var users: {
        const synced = meta.users || [];
        const all = passwdUsers.map(u => Object.assign({}, u, synced.find(s => s.name === u.name) || {}));
        for (const s of synced)
            if (!all.some(u => u.name === s.name))
                all.push(s);
        return all;
    }
    property var sessions: []
    property string user: ""
    property string session: ""
    readonly property var userInfo: users.find(u => u.name === user) || ({ name: user })
    readonly property var sessionInfo: sessions.find(s => s.id === session) || null

    // idle | auth (waiting for greetd) | answer (greetd asks something else) | launching
    property string phase: "idle"
    property string error: ""
    property string info: ""
    property var pending: null         // the password, until greetd asks for it
    property bool answered: false      // a question besides the password was answered

    property var keyboard: null        // Compositor.queryKeyboard()
    property string armed: ""          // power action awaiting its second click
    property bool largeText: false
    property bool highContrast: false
    // Tests: power buttons only report what they would do.
    readonly property bool dryRun: Platform.env("BIFROST_GREETER_DRYRUN") === "1"
    property string lastPower: ""

    signal clearField

    function load() {
        meta = JSON.parse(metaFile.readNow() || "{}");
        memory = JSON.parse(memoryFile.readNow() || "{}");
        largeText = memory.largeText === true;
        highContrast = memory.highContrast === true;
        applyAccessibility();
    }

    function chooseDefaults() {
        if (!users.some(u => u.name === user))
            user = users.some(u => u.name === memory.lastUser) ? memory.lastUser : (users[0] ? users[0].name : "");
        pickSession();
    }

    function pickSession() {
        const remembered = (memory.sessions || {})[user];
        session = sessions.some(s => s.id === remembered) ? remembered : sessions.some(s => s.id === "hyprland") ? "hyprland" : (sessions[0] ? sessions[0].id : "");
    }

    function remember() {
        const m = JSON.parse(JSON.stringify(memory));
        m.lastUser = user;
        m.sessions = m.sessions || {};
        m.sessions[user] = session;
        m.largeText = largeText;
        m.highContrast = highContrast;
        memory = m;
        memoryFile.write(JSON.stringify(m, null, 2) + "\n");
    }

    function selectUser(name: string) {
        if (phase === "auth" || phase === "launching" || !users.some(u => u.name === name))
            return;
        cancel();
        user = name;
        pickSession();
    }

    function cancel() {
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        phase = "idle";
        pending = null;
        info = "";
    }

    function submit(text: string) {
        error = "";
        if (!Greetd.available) {
            error = I18n.tr("The login service (greetd) is not running.");
            return;
        }
        if (phase === "answer") {
            phase = "auth";
            answered = true;
            Greetd.respond(text);
            return;
        }
        if (phase !== "idle" || user === "" || !sessionInfo)
            return;
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        pending = text;
        answered = false;
        phase = "auth";
        Greetd.createSession(user);
    }

    function power(action: string) {
        if ((action === "poweroff" || action === "reboot") && armed !== action) {
            armed = action;
            disarm.restart();
            return;
        }
        armed = "";
        lastPower = action;
        if (dryRun)
            console.info("[bifrost] greeter: would run systemctl", action);
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    function applyAccessibility() {
        Config.setTransient("appearance.font.scale", largeText ? 1.3 : undefined);
        for (const [k, v] of [["materials.all.transparency", 0], ["materials.all.border", true], ["materials.all.borderWidth", 2], ["materials.all.borderOpacity", 100], ["materials.all.borderColor", "#FFFFFF"], ["materials.all.glow", 0], ["appearance.foreground.dark", "#FFFFFF"], ["appearance.foreground.light", "#000000"]])
            Config.setTransient(k, highContrast ? v : undefined);
    }

    function toggleLargeText() {
        largeText = !largeText;
        applyAccessibility();
        remember();
    }

    function toggleHighContrast() {
        highContrast = !highContrast;
        applyAccessibility();
        remember();
    }

    Component.onCompleted: {
        load();
        passwdReader.running = true;
        sessionReader.running = true;
    }

    WatchedFile {
        id: metaFile

        watch: false
        path: greeter.cacheDir + "/greeter.json"
    }

    WatchedFile {
        id: memoryFile

        watch: false
        path: greeter.cacheDir + "/state/memory.json"
    }

    WatchedFile {
        id: marker

        watch: false
        path: greeter.runDir !== "" ? greeter.runDir + "/launched" : ""
    }

    Process {
        id: passwdReader

        command: ["cat", "/etc/passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                greeter.passwdUsers = Logic.parseUsers(text);
                greeter.chooseDefaults();
            }
        }
    }

    Process {
        id: sessionReader

        command: ["sh", "-c", "for f in \"$1\"/*.desktop; do [ -f \"$f\" ] && printf '@@%s\\n' \"$f\" && cat \"$f\" && echo; done", "sh", greeter.sessionsDir]
        stdout: StdioCollector {
            onStreamFinished: {
                greeter.sessions = Logic.parseSessions(text);
                greeter.chooseDefaults();
            }
        }
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: greeter.armed = ""
    }

    // Caps Lock and the keyboard layout, from the compositor.
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 400
        onTriggered: Compositor.queryKeyboard(k => greeter.keyboard = k)
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool) {
            if (responseRequired && !echoResponse && greeter.pending !== null) {
                const p = greeter.pending;
                greeter.pending = null;
                Greetd.respond(p);
                return;
            }
            if (responseRequired) {
                // Something besides the password (a code): ask in the field.
                greeter.info = message;
                greeter.phase = "answer";
                greeter.clearField();
                return;
            }
            if (error)
                greeter.error = message;
            else
                greeter.info = message;
        }

        function onAuthFailure(message: string) {
            greeter.phase = "idle";
            greeter.pending = null;
            greeter.info = "";
            greeter.error = greeter.answered ? I18n.tr("That was not accepted. Try again.") : I18n.tr("Wrong password. Try again.");
            greeter.clearField();
        }

        function onError(error: string) {
            greeter.phase = "idle";
            greeter.pending = null;
            greeter.error = I18n.tr("Could not log in: %1").arg(error);
            greeter.clearField();
        }

        function onReadyToLaunch() {
            const s = greeter.sessionInfo;
            if (!s) {
                greeter.cancel();
                greeter.error = I18n.tr("Choose a session first.");
                return;
            }
            greeter.phase = "launching";
            greeter.remember();
            if (marker.path !== "")
                marker.writeNow(s.id + "\n");
            Greetd.launch(Logic.commandOf(s.exec), Logic.sessionEnv(s), true);
        }
    }

    // Tests and scripts (same user only): state, and what the card's controls do.
    IpcHandler {
        target: "greeter"

        function status(): string {
            return JSON.stringify({
                available: Greetd.available,
                state: Greetd.state,
                phase: greeter.phase,
                user: greeter.user,
                users: greeter.users.map(u => u.name),
                session: greeter.session,
                sessions: greeter.sessions.map(s => s.id),
                error: greeter.error,
                info: greeter.info,
                capsLock: greeter.keyboard ? greeter.keyboard.capsLock : null,
                layouts: greeter.keyboard ? greeter.keyboard.layouts : [],
                largeText: greeter.largeText,
                highContrast: greeter.highContrast,
                wallpaper: Config.values.wallpaper.path,
                avatar: greeter.userInfo.avatar || "",
                armed: greeter.armed,
                lastPower: greeter.lastPower
            });
        }

        // What the power buttons do (a shutdown/restart needs two calls, like two clicks).
        function power(action: string): void {
            if (["suspend", "reboot", "poweroff"].indexOf(action) >= 0)
                greeter.power(action);
        }

        function login(password: string): void {
            greeter.submit(password);
        }

        function selectUser(name: string): void {
            greeter.selectUser(name);
        }

        function selectSession(id: string): void {
            if (greeter.sessions.some(s => s.id === id))
                greeter.session = id;
        }

        function accessibility(which: string): void {
            if (which === "largeText")
                greeter.toggleLargeText();
            else if (which === "highContrast")
                greeter.toggleHighContrast();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property bool primary: modelData === (Quickshell.screens.find(s => Compositor.focusedMonitor && s.name === Compositor.focusedMonitor.name) || Quickshell.screens[0])

            screen: modelData
            color: Theme.palette.void
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "bifrost:greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            GreeterSurface {
                anchors.fill: parent
                login: greeter
                primary: window.primary
            }
        }
    }
}
