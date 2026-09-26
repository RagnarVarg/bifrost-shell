import QtQuick
import qs.Compat
import Quickshell
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar

// A tray item's DBus menu drawn as Bifrost glass. Submenus open in place
// with a back row. Not opened on hover: a left click on most tray icons
// activates the app, not the menu.
BarMenu {
    id: menu

    property var handle: null
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : handle

    openOnHover: false
    onDismissed: stack = []

    QsMenuOpener {
        id: opener

        menu: menu.current
    }

    Column {
        id: list

        width: Theme.space.xxxl * 9

        Item {
            visible: menu.stack.length > 0
            width: parent.width
            height: Theme.control.height.md

            StateLayer {
                anchors.fill: parent
                radius: Theme.control.radius
                hovered: backMouse.containsMouse
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.sm

                BIcon {
                    name: "chevron-left"
                    size: Theme.icon.size.sm
                    anchors.verticalCenter: parent.verticalCenter
                }

                BText {
                    text: I18n.tr("Back")
                    role: "label"
                    tone: "muted"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: backMouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: menu.stack = menu.stack.slice(0, -1)
            }
        }

        Repeater {
            model: opener.children ? opener.children.values : []

            delegate: Item {
                id: entry

                required property var modelData

                width: list.width
                height: modelData.isSeparator ? Theme.space.md : Theme.control.height.md

                BDivider {
                    visible: entry.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - Theme.space.md * 2
                }

                StateLayer {
                    visible: !entry.modelData.isSeparator
                    anchors.fill: parent
                    radius: Theme.control.radius
                    hovered: entryMouse.containsMouse && entry.modelData.enabled
                    pressed: entryMouse.pressed
                }

                Row {
                    visible: !entry.modelData.isSeparator
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.sm
                    opacity: entry.modelData.enabled ? 1 : Theme.opacity.disabled

                    Item {
                        width: Theme.icon.size.sm
                        height: Theme.icon.size.sm
                        anchors.verticalCenter: parent.verticalCenter

                        BIcon {
                            anchors.fill: parent
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState === Qt.Checked
                            name: "check"
                            size: Theme.icon.size.sm
                        }

                        Image {
                            anchors.fill: parent
                            visible: entry.modelData.buttonType === QsMenuButtonType.None && entry.modelData.icon !== ""
                            source: Platform.iconPath(entry.modelData.icon, "")
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                    }

                    BText {
                        width: parent.width - Theme.icon.size.sm * 2 - Theme.space.sm * 2
                        text: entry.modelData.text.replace(/_(?!_)/g, "")
                        role: "label"
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BIcon {
                        visible: entry.modelData.hasChildren
                        name: "chevron-right"
                        size: Theme.icon.size.sm
                        color: Theme.color.iconMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    enabled: !entry.modelData.isSeparator && entry.modelData.enabled
                    hoverEnabled: true
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            menu.stack = menu.stack.concat([entry.modelData]);
                        } else {
                            entry.modelData.triggered();
                            menu.close();
                        }
                    }
                }
            }
        }
    }
}
