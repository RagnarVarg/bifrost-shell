import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// System state, not a preference: a failed/cancelled authentication must
// never make the toggle claim that the login screen was changed.
Column {
    id: control
    spacing: Theme.space.md
    property var loginState: ({})
    property bool busy: false
    property string error: ""
    property bool applied: false
    function refresh() {
        busy = true;
        Ctl.run(["greeter", "status", "--json"], (ok, out, data) => {
            loginState = data || {};
            if (!ok) error = out;
            busy = false;
        }, control);
    }
    function change(on) {
        busy = true;
        error = "";
        applied = false;
        Ctl.run(["greeter", on ? "enable" : "disable", "--json"], (ok, out, data) => {
            if (!ok) error = data && data.error ? data.error : out;
            applied = ok;
            refresh();
        }, control, 120000);
    }
    Component.onCompleted: refresh()
    Row {
        width: parent.width
        spacing: Theme.space.md
        BText {
            width: parent.width - toggle.width - parent.spacing
            text: I18n.tr("Use the Bifrost login theme")
            role: "label"
            wrapMode: Text.WordWrap
        }
        BToggle {
            id: toggle
            checked: control.loginState.enabled === true
            enabled: !control.busy && (checked ? control.loginState.canDisable === true : control.loginState.canEnable === true)
            onToggled: on => control.change(on)
        }
    }
    BText {
        width: parent.width
        text: control.busy ? I18n.tr("Checking login screen…") :
              !control.loginState.installed ? I18n.tr("Bifrost login theme is not installed. It requires greetd; the current login manager is %1.").arg(control.loginState.displayManager || "?") :
              control.loginState.enabled && !control.loginState.canDisable ? I18n.tr("The previous login configuration backup is missing; automatic restoration is unavailable.") :
              !control.loginState.canEnable ? I18n.tr("Login screen installation is incomplete. Run the Bifrost installer again.") :
              I18n.tr("Administrator authentication is required. Changes take effect after reboot. Switching off restores the previous login manager.")
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }
    BText {
        width: parent.width
        visible: control.applied
        text: I18n.tr("Login theme updated for the next reboot. Your current session stays open.")
        wrapMode: Text.WordWrap
    }
    BText {
        width: parent.width
        visible: control.error !== ""
        text: control.error
        tone: "warning"
        wrapMode: Text.WordWrap
    }
    BButton {
        text: I18n.tr("Refresh")
        enabled: !control.busy
        onClicked: control.refresh()
    }
}
