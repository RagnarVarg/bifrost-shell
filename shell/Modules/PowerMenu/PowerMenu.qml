import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text
import qs.Modules
import qs.Services

// Lock / log out / suspend / restart / power off. Destructive actions need a
// second click (power.confirm); what the run mode forbids is shown disabled
// with the reason.
Scope {
    id: menu

    readonly property bool open: ShellState.powerMenuOpen
    property int current: 0
    property string armed: ""

    readonly property var actions: [
        { id: "lock", icon: "lock", label: I18n.tr("Lock"), enabled: Session.canLock, confirm: false, run: () => Session.lock() },
        { id: "logout", icon: "logout", label: I18n.tr("Log out"), enabled: Session.canLogout, confirm: true, run: () => Session.logout() },
        { id: "suspend", icon: "sleep", label: I18n.tr("Sleep"), enabled: Session.canPower, confirm: false, run: () => Session.suspend() },
        { id: "reboot", icon: "restart", label: I18n.tr("Restart"), enabled: Session.canPower, confirm: true, run: () => Session.reboot() },
        { id: "poweroff", icon: "power", label: I18n.tr("Shut down"), enabled: Session.canPower, confirm: true, run: () => Session.poweroff() }
    ]

    function close() {
        ShellState.powerMenuOpen = false;
        armed = "";
    }

    function trigger(a) {
        if (!a.enabled)
            return;
        if (a.confirm && Config.values.power.confirm && armed !== a.id) {
            armed = a.id;
            disarm.restart();
            return;
        }
        close();
        a.run();
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: menu.armed = ""
    }

    PanelWindow {
        id: window

        screen: Quickshell.screens.find(s => s.name === ShellState.powerMenuScreen) || Quickshell.screens[0]
        visible: menu.open || glass.opacity > 0
        color: "transparent"
        WlrLayershell.namespace: RunMode.layerNamespace("power")
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        onVisibleChanged: if (visible && menu.open) {
            menu.current = menu.actions.findIndex(a => a.enabled);
            keys.forceActiveFocus();
        }

        MouseArea {
            anchors.fill: parent
            enabled: menu.open
            onClicked: menu.close()
        }

        GlassSurface {
            id: glass

            material: Theme.materials.launcher
            anchors.centerIn: parent
            width: row.implicitWidth + Theme.space.xl * 2
            height: column.implicitHeight + Theme.space.xl * 2
            opacity: menu.open ? 1 : 0
            scale: menu.open ? 1 : 0.98

            Behavior on opacity {
                BNumberAnimation {}
            }

            Behavior on scale {
                BNumberAnimation {
                    curve: "decelerate"
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: keys

                focus: menu.open
                Keys.onEscapePressed: menu.close()
                Keys.onLeftPressed: menu.current = Math.max(0, menu.current - 1)
                Keys.onRightPressed: menu.current = Math.min(menu.actions.length - 1, menu.current + 1)
                Keys.onReturnPressed: menu.trigger(menu.actions[menu.current])
                Keys.onEnterPressed: menu.trigger(menu.actions[menu.current])
            }

            Column {
                id: column

                x: Theme.space.xl
                y: Theme.space.xl
                spacing: Theme.space.lg

                Row {
                    id: row

                    spacing: Theme.space.md

                    Repeater {
                        model: menu.actions

                        delegate: Item {
                            id: tile

                            required property int index
                            required property var modelData
                            readonly property bool armed: menu.armed === modelData.id

                            width: Theme.control.height.lg * 2.6
                            height: Theme.control.height.lg * 2.6
                            opacity: modelData.enabled ? 1 : Theme.opacity.disabled

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radius.lg
                                color: Theme.color.controlFill
                                border.width: Theme.border.hairline
                                border.color: tile.armed ? Theme.color.danger : Theme.color.hairline
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: Theme.radius.lg
                                hovered: mouse.containsMouse && tile.modelData.enabled
                                pressed: mouse.pressed
                                selected: menu.current === tile.index && tile.modelData.enabled
                                active: tile.armed
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.space.sm

                                BIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: tile.modelData.icon
                                    size: Theme.icon.size.xl
                                    color: tile.armed ? Theme.color.danger : Theme.color.text
                                }

                                BText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tile.armed ? I18n.tr("Again") : tile.modelData.label
                                    role: "label"
                                    tone: tile.armed ? "danger" : "primary"
                                }
                            }

                            MouseArea {
                                id: mouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: tile.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: if (tile.modelData.enabled)
                                    menu.current = tile.index
                                onClicked: menu.trigger(tile.modelData)
                            }
                        }
                    }
                }

                BText {
                    visible: text !== ""
                    width: row.width
                    horizontalAlignment: Text.AlignHCenter
                    text: menu.armed !== "" ? I18n.tr("Click again to confirm") : Session.reason()
                    role: "caption"
                    tone: menu.armed !== "" ? "danger" : "muted"
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
