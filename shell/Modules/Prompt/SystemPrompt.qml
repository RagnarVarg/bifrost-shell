import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.Text
import qs.Modules

// A system question on the focused screen (Bluetooth pairing, polkit
// authentication): icon, title, explanation, the asker's own content, and
// Cancel / accept. Enter accepts, Escape cancels. The glass is the
// notifications material (namespace bifrost:prompt).
//   SystemPrompt { open: …; title: …; body: …; onAccepted: …; onRejected: …
//                  BTextField { … } }
PanelWindow {
    id: prompt

    property bool open: false
    property string icon: "info"
    property string title: ""
    property string body: ""
    property string acceptText: I18n.tr("OK")
    property bool acceptVisible: true
    property bool acceptEnabled: true
    // Takes the keyboard while open (password entry), instead of on demand.
    property bool exclusiveKeyboard: false
    // What gets keyboard focus when the prompt opens or its content changes;
    // null = the prompt itself (Enter/Escape).
    property Item focusItem: null
    default property alias content: extra.data

    signal accepted
    signal rejected

    function refocus() {
        if (open)
            (focusItem || keys).forceActiveFocus();
    }

    screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen()) || Quickshell.screens[0]
    visible: open || glass.opacity > 0
    color: "transparent"
    WlrLayershell.namespace: RunMode.layerNamespace("prompt")
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        item: glass
    }
    implicitWidth: glass.width + glass.shadowExtent * 2
    implicitHeight: glass.height + glass.shadowExtent * 2

    onOpenChanged: refocus()
    onFocusItemChanged: refocus()

    GlassSurface {
        id: glass

        material: Theme.materials.notifications
        x: shadowExtent
        y: shadowExtent
        width: Theme.layout.promptWidth
        height: column.implicitHeight + Theme.space.xl * 2
        opacity: prompt.open ? 1 : 0
        scale: prompt.open ? 1 : 0.98

        Behavior on opacity {
            BNumberAnimation {}
        }

        Behavior on scale {
            BNumberAnimation {
                curve: "decelerate"
            }
        }

        Item {
            id: keys

            Keys.onEscapePressed: prompt.rejected()
            Keys.onReturnPressed: if (prompt.acceptVisible && prompt.acceptEnabled)
                prompt.accepted()
            Keys.onEnterPressed: if (prompt.acceptVisible && prompt.acceptEnabled)
                prompt.accepted()
        }

        Column {
            id: column

            x: Theme.space.xl
            y: Theme.space.xl
            width: parent.width - Theme.space.xl * 2
            spacing: Theme.space.md

            Row {
                spacing: Theme.space.md

                BIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: prompt.icon
                    size: Theme.icon.size.lg
                    color: Theme.color.text
                }

                BText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: column.width - Theme.icon.size.lg - Theme.space.md
                    text: prompt.title
                    role: "title"
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            BText {
                visible: text !== ""
                width: parent.width
                text: prompt.body
                role: "body"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            Column {
                id: extra

                width: parent.width
                spacing: Theme.space.md
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.space.sm

                BButton {
                    text: I18n.tr("Cancel")
                    variant: "ghost"
                    onClicked: prompt.rejected()
                }

                BButton {
                    visible: prompt.acceptVisible
                    enabled: prompt.acceptEnabled
                    text: prompt.acceptText
                    variant: "primary"
                    onClicked: prompt.accepted()
                }
            }
        }
    }
}
