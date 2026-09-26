import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// The session's polkit authentication agent (Quickshell's PolkitAgent): when
// an app asks for administrator rights (pkexec, GParted, system settings) it
// asks for the password here. Only the session shell registers: polkit has
// one agent per session.
Scope {
    id: root

    readonly property var flow: agent.flow
    readonly property var identities: flow ? flow.identities : []

    PolkitAgent {
        id: agent

        path: "/org/bifrost/PolkitAgent"
        // Registers when created; only the session shell creates it.
    }

    IpcHandler {
        target: "polkit"

        function status(): string {
            return JSON.stringify({ registered: agent.isRegistered, active: agent.isActive, message: root.flow ? root.flow.message : "", identities: root.identities.map(i => i.displayName) });
        }

        function cancel(): void {
            if (root.flow)
                root.flow.cancelAuthenticationRequest();
        }
    }

    SystemPrompt {
        id: prompt

        open: root.flow !== null && !root.flow.isCompleted
        icon: "lock"
        title: I18n.tr("Authentication required")
        body: root.flow ? root.flow.message : ""
        acceptText: I18n.tr("Authenticate")
        acceptEnabled: root.flow !== null && root.flow.isResponseRequired
        exclusiveKeyboard: true
        focusItem: field.input
        onAccepted: root.submit()
        onRejected: if (root.flow)
            root.flow.cancelAuthenticationRequest()

        BDropdown {
            visible: root.identities.length > 1
            width: parent.width
            model: root.identities.map(i => ({ value: i.displayName, label: i.displayName }))
            currentValue: root.flow && root.flow.selectedIdentity ? root.flow.selectedIdentity.displayName : null
            onActivated: v => {
                const i = root.identities.find(x => x.displayName === v);
                if (i && root.flow)
                    root.flow.selectedIdentity = i;
            }
        }

        BTextField {
            id: field

            width: parent.width
            icon: "lock"
            password: root.flow ? !root.flow.responseVisible : true
            placeholder: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : I18n.tr("Password")
            enabled: root.flow !== null && root.flow.isResponseRequired
            onAccepted: root.submit()
            onKeyPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    prompt.rejected();
                }
            }
        }

        BText {
            visible: text !== ""
            width: parent.width
            text: !root.flow ? "" : root.flow.supplementaryMessage || (root.flow.failed ? I18n.tr("Authentication failed. Try again.") : "")
            role: "caption"
            tone: root.flow && (root.flow.supplementaryIsError || root.flow.failed) ? "danger" : "muted"
            wrapMode: Text.WordWrap
        }
    }

    function submit() {
        if (!flow || !flow.isResponseRequired)
            return;
        flow.submit(field.text);
        field.text = "";
    }

    Connections {
        target: root.flow

        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired)
                prompt.refocus();
        }
    }
}
