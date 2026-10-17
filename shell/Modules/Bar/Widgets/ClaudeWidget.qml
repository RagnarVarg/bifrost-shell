import QtQuick
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Claude Code sessions, from bin/bifrost-claude-hook (Claude Code hooks →
// $XDG_RUNTIME_DIR/bifrost/claude.json). An Ansuz rune (ᚨ, the rune of speech
// and counsel): it breathes while Claude works, turns accent with a dot when a
// session needs you (permission, a question) and gets a quiet dot when a turn
// is done. Hidden while no session runs. The menu lists the sessions; a click
// on one focuses its terminal window.
BarWidget {
    id: widget

    property var sessions: []

    readonly property var waiting: sessions.filter(s => s.state === "waiting")
    readonly property var working: sessions.filter(s => s.state === "working")
    readonly property var done: sessions.filter(s => s.state === "done")
    readonly property string mood: waiting.length ? "waiting" : working.length ? "working" : done.length ? "done" : "idle"

    shown: sessions.length > 0
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function parse(text: string) {
        try {
            const data = JSON.parse(text || "{}");
            sessions = Array.isArray(data.sessions) ? data.sessions.filter(s => s && s.id) : [];
        } catch (e) {
            sessions = [];
        }
    }

    // The terminal window of a session: the nearest of its ancestor
    // processes that owns a window.
    function windowPid(session: var): int {
        const owners = new Set(Compositor.windows.map(w => w.pid));
        return (session.pids || []).find(p => owners.has(p)) || 0;
    }

    function focus(session: var) {
        const pid = windowPid(session);
        if (pid)
            Compositor.focusProcessWindow(pid);
        menu.close();
    }

    function stateText(session: var): string {
        if (session.state === "waiting")
            return session.message || I18n.tr("Needs your answer");
        if (session.state === "working")
            return I18n.tr("Working…");
        if (session.state === "done")
            return I18n.tr("Done — your turn");
        return I18n.tr("Ready");
    }

    WatchedFile {
        path: Paths.xdgRuntime + "/bifrost/claude.json"
        onContentChanged: (content, exists) => widget.parse(exists ? content : "")
    }

    // Sessions whose Claude process ended without a SessionEnd hook.
    Timer {
        interval: 30000
        repeat: true
        running: widget.sessions.length > 0
        onTriggered: Exec.run(["python3", Paths.repoDir + "/bin/bifrost-claude-hook", "--prune"], null, 5000, widget)
    }

    BarButton {
        id: button

        anchors.fill: parent
        padding: Theme.space.sm
        vertical: widget.vertical
        selected: menu.isOpen
        onClicked: menu.click()

        Item {
            implicitWidth: Theme.icon.size.bar
            implicitHeight: Theme.icon.size.bar

            Canvas {
                id: rune

                // Same 11:15 proportion as the system menu's rune.
                height: Theme.icon.size.bar - 3
                width: Math.round(height * 11 / 15)
                anchors.centerIn: parent

                readonly property color color: widget.mood === "waiting" ? Theme.color.accent : Theme.color.text
                onColorChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = rune.color;
                    ctx.lineWidth = 1.6;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    const x = width, y = height;
                    ctx.beginPath();
                    // Ansuz: a stave with two arms falling to the right.
                    ctx.moveTo(x * 0.28, y * 0.08);
                    ctx.lineTo(x * 0.28, y * 0.92);
                    ctx.moveTo(x * 0.28, y * 0.10);
                    ctx.lineTo(x * 0.80, y * 0.36);
                    ctx.moveTo(x * 0.28, y * 0.38);
                    ctx.lineTo(x * 0.80, y * 0.64);
                    ctx.stroke();
                }

                SequentialAnimation on opacity {
                    running: widget.mood === "working" && Theme.motion.enabled
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        rune.opacity = 1

                    NumberAnimation {
                        to: Theme.opacity.disabled
                        duration: Theme.motion.duration.emphasis * 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: Theme.motion.duration.emphasis * 2
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Needs you (accent) / turn done (quiet).
            Rectangle {
                visible: widget.mood === "waiting" || widget.mood === "done"
                anchors.right: parent.right
                anchors.top: parent.top
                width: Theme.space.sm
                height: width
                radius: width / 2
                color: widget.mood === "waiting" ? Theme.color.accent : Theme.color.textMuted
            }
        }

        BText {
            visible: widget.sessions.length > 1
            text: widget.sessions.length
            role: "mono"
            tone: widget.mood === "waiting" ? "accent" : "muted"
        }
    }

    StatusMenu {
        id: menu

        title: "Claude Code"
        bar: widget.bar
        anchorItem: button

        Repeater {
            // Needs you first, then working, then the rest; newest first.
            model: widget.sessions.slice().sort((a, b) => {
                const order = ["waiting", "working", "done"];
                const rank = s => order.includes(s.state) ? order.indexOf(s.state) : order.length;
                return rank(a) - rank(b) || (b.updated || 0) - (a.updated || 0);
            })

            BListRow {
                required property var modelData

                width: parent ? parent.width : 0
                icon: ({ waiting: "warning", working: "clock", done: "check" })[modelData.state] || "minus"
                title: modelData.project || modelData.cwd || "Claude Code"
                subtitle: widget.stateText(modelData)
                selected: modelData.state === "waiting"
                onClicked: widget.focus(modelData)
            }
        }
    }
}
