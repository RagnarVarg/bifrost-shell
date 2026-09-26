import QtQuick
import Quickshell
import Quickshell.Io
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import qs.Modules.Prompt
import qs.Services

// The session's Bluetooth pairing agent: tools/bt_agent.py registers with
// BlueZ and hands each question here (confirm a code, type a code on the
// device, enter a PIN, allow a service); the answer goes back on its stdin.
// Only the session shell runs it: BlueZ has one default agent per system.
// Pairing itself starts wherever the user is (Settings, control center, a
// phone) – the prompt appears here, on the focused screen.
Scope {
    id: agent

    property var requests: []          // oldest first: { id, kind, name, device, passkey, entered }
    readonly property var current: requests.length > 0 ? requests[0] : null
    readonly property bool entry: current !== null && (current.kind === "pin" || current.kind === "passkey")
    property string error: ""

    function remove(id) {
        requests = requests.filter(r => r.id !== id);
    }

    function answer(accept: bool) {
        if (!current)
            return;
        const r = current;
        if (r.kind === "display") {
            // Nothing to answer: the device sends the code. Cancelling stops pairing.
            if (!accept) {
                const address = r.device.split("/").pop().slice(4).replace(/_/g, ":");
                const d = BluetoothStatus.allDevices.find(x => x.address === address);
                if (d)
                    d.cancelPair();
            }
        }
        watcher.write(JSON.stringify({ id: r.id, accept: accept, value: accept && agent.entry ? field.text.trim() : "" }));
        remove(r.id);
    }

    function handle(text: string) {
        let e;
        try {
            e = JSON.parse(text);
        } catch (err) {
            return;
        }
        if (e.event === "request")
            requests = requests.concat([e]);
        else if (e.event === "update")
            requests = requests.map(r => r.id === e.id ? Object.assign({}, r, { entered: e.entered }) : r);
        else if (e.event === "cancel" || e.event === "done")
            remove(e.id);
        else if (e.event === "error")
            error = e.message;
        else if (e.event === "ready")
            error = "";
    }

    LineWatcher {
        id: watcher

        active: RunMode.isProduction && BluetoothStatus.available
        writable: true
        restartMs: 10000
        command: ["python3", Paths.repoDir + "/tools/bt_agent.py"]
        onLine: text => agent.handle(text)
        onActiveChanged: if (!active)
            agent.requests = []
    }

    // Shows a prompt without an agent behind it (for checking the look):
    // qs ipc call bluetoothagent preview confirm|display|pin|passkey|service|authorize,
    // then respond true|false
    IpcHandler {
        target: "bluetoothagent"

        function preview(kind: string): void {
            agent.handle(JSON.stringify({ event: "request", id: -Date.now(), kind: kind, device: "/org/bluez/hci0/dev_00_00_00_00_00_00", name: "Keyboard K380", passkey: kind === "confirm" || kind === "display" ? "042317" : null, entered: kind === "display" ? 2 : null }));
        }

        // Answers the prompt on screen, like its buttons.
        function respond(accept: bool): void {
            agent.answer(accept);
        }

        function status(): string {
            return JSON.stringify({ running: watcher.active, error: agent.error, pending: agent.requests.map(r => r.kind) });
        }
    }

    onErrorChanged: if (error !== "")
        console.warn("[bifrost] bluetooth agent:", error)

    onCurrentChanged: {
        field.text = "";
        prompt.refocus();
    }

    SystemPrompt {
        id: prompt

        open: agent.current !== null
        icon: "bluetooth"
        title: !agent.current ? "" : agent.current.kind === "service" ? I18n.tr("Allow %1 to connect?").arg(agent.current.name) : I18n.tr("Pair with %1?").arg(agent.current.name)
        body: !agent.current ? "" : ({
                confirm: I18n.tr("Check that the device shows the same code."),
                authorize: I18n.tr("The device asks to pair without a code."),
                service: I18n.tr("The device asks to use a service on this computer."),
                display: I18n.tr("Type this code on the device, then press Enter on it."),
                pin: I18n.tr("Enter the PIN shown on the device, or its default PIN."),
                passkey: I18n.tr("Enter the code shown on the device.")
            })[agent.current.kind] || ""
        acceptText: agent.current && agent.current.kind === "service" ? I18n.tr("Allow") : I18n.tr("Pair")
        acceptVisible: agent.current !== null && agent.current.kind !== "display"
        focusItem: agent.entry ? field.input : null
        onAccepted: agent.answer(true)
        onRejected: agent.answer(false)

        BText {
            visible: agent.current !== null && !!agent.current.passkey
            anchors.horizontalCenter: parent.horizontalCenter
            text: agent.current && agent.current.passkey ? String(agent.current.passkey) : ""
            role: "display"
            font.letterSpacing: Theme.space.sm
        }

        BText {
            visible: agent.current !== null && agent.current.kind === "display" && agent.current.entered !== null && agent.current.entered !== undefined
            anchors.horizontalCenter: parent.horizontalCenter
            text: agent.current ? I18n.tr("%n digits typed", agent.current.entered || 0) : ""
            role: "caption"
            tone: "muted"
        }

        BTextField {
            id: field

            visible: agent.entry
            width: parent.width
            placeholder: agent.current && agent.current.kind === "passkey" ? "000000" : "0000"
            input.inputMethodHints: agent.current && agent.current.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
            onAccepted: agent.answer(true)
            onKeyPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    agent.answer(false);
                }
            }
        }
    }
}
