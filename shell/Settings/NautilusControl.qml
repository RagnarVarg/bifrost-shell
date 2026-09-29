import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Files (Nautilus) reads its GTK style once when it starts, so the pane
// transparency reaches open windows only after a restart; blur is live.
// Restarting reopens each window at its folder (not its extra tabs).
Row {
    id: control

    property bool busy: false
    property string message: ""

    function restart() {
        busy = true;
        message = "";
        Ctl.run(["nautilus", "restart", "--json"], (ok, out, data) => {
            message = !ok ? I18n.tr("Couldn't restart Files: %1").arg(data && data.message ? data.message : out)
                    : data && data.reopened === null ? I18n.tr("Files isn't running; the style applies when it starts.")
                    : I18n.tr("Files restarted; windows reopened: %1").arg(data ? data.reopened : 0);
            busy = false;
        }, control, 20000);
    }

    spacing: Theme.space.md

    BText {
        width: parent.width - restartButton.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: control.message !== "" ? control.message : I18n.tr("Transparency reaches open Files windows after a restart. Restarting reopens each window at its folder; extra tabs close.")
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }

    BButton {
        id: restartButton

        anchors.verticalCenter: parent.verticalCenter
        size: "sm"
        icon: "restart"
        text: I18n.tr("Restart Files")
        enabled: !control.busy
        onClicked: control.restart()
    }
}
