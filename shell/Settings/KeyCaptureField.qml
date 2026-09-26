import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text
import "KeyNames.js" as KeyNames

// Records a key combination. While recording, the compositor's shortcuts are
// suspended (Compositor.setKeyCapture) so that combinations already in use,
// like Super+Q, reach this field instead of running. Recording ends with the
// first non-modifier key, Escape, losing focus or after `timeoutMs`; Super+Esc
// always gives the compositor its shortcuts back. "Type" edits the text form
// (mouse buttons, keycodes).
Column {
    id: root

    property string keys: ""
    property bool recording: false
    property bool typing: false
    property int timeoutMs: 15000
    readonly property bool captures: Compositor.supports("keyCapture")

    signal recorded(string keys)

    spacing: Theme.space.sm

    function start() {
        typing = false;
        recording = true;
        area.forceActiveFocus();
        if (captures)
            Compositor.setKeyCapture(true);
        timeout.restart();
    }

    function stop() {
        if (!recording)
            return;
        recording = false;
        timeout.stop();
        if (captures)
            Compositor.setKeyCapture(false);
    }

    Component.onDestruction: stop()

    Timer {
        id: timeout

        interval: root.timeoutMs
        onTriggered: root.stop()
    }

    Item {
        width: parent.width
        height: Theme.control.height.lg

        Rectangle {
            anchors.fill: parent
            visible: !root.typing
            radius: Theme.radius.md
            color: Theme.color.fieldFill
            border.width: root.recording ? Theme.border.focus : Theme.border.hairline
            border.color: root.recording ? Theme.color.focus : Theme.color.hairline

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                hovered: mouse.containsMouse && !root.recording
            }

            Item {
                id: area

                anchors.fill: parent
                focus: root.recording
                onActiveFocusChanged: if (!activeFocus)
                    root.stop()
                Keys.onPressed: e => {
                    if (!root.recording)
                        return;
                    e.accepted = true;
                    if (e.key === Qt.Key_Escape && !(e.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier))) {
                        root.stop();
                        return;
                    }
                    const combo = KeyNames.fromEvent(e);
                    if (combo === "")
                        return;
                    root.keys = combo;
                    root.stop();
                    root.recorded(combo);
                }
            }

            KeyChips {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                visible: root.keys !== ""
                keys: root.keys
            }

            BText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                visible: root.keys === ""
                text: root.recording ? I18n.tr("Press the new shortcut…") : I18n.tr("Click to record a shortcut")
                tone: "faint"
            }

            BText {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                text: root.recording ? I18n.tr("Esc cancels") : root.keys !== "" ? I18n.tr("Click to record again") : ""
                role: "caption"
                tone: "muted"
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.recording ? root.stop() : root.start()
            }
        }

        BTextField {
            id: text

            anchors.fill: parent
            visible: root.typing
            placeholder: "SUPER + SHIFT + K"
            onAccepted: t => {
                root.keys = t.trim();
                root.typing = false;
                root.recorded(root.keys);
            }
        }
    }

    Row {
        spacing: Theme.space.sm

        BButton {
            size: "sm"
            variant: "ghost"
            text: root.typing ? I18n.tr("Record instead") : I18n.tr("Type it")
            onClicked: {
                root.stop();
                root.typing = !root.typing;
                if (root.typing) {
                    text.text = root.keys;
                    text.input.forceActiveFocus();
                }
            }
        }

        BText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.recording && root.captures
            text: I18n.tr("Your shortcuts are paused while recording (Super+Esc resumes them).")
            role: "caption"
            tone: "muted"
        }
    }
}
