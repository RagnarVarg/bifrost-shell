import QtQuick
import qs.Compat
import qs.Core
import qs.Services
import qs.Components.State

// StatusNotifier icons. Left: activate (or menu for menu-only items),
// right: menu, middle: secondary action, wheel: scroll.
BarWidget {
    id: widget

    shown: Tray.items.length > 0
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    BarRow {
        id: row

        anchors.centerIn: parent
        vertical: widget.vertical
        spacing: Theme.space.xxs

        Repeater {
            model: Tray.items

            delegate: Item {
                id: icon

                required property int index
                required property var modelData
                readonly property bool hovered: mouse.containsMouse

                width: Theme.control.height.sm
                height: Theme.control.height.sm

                StateLayer {
                    anchors.fill: parent
                    radius: Theme.control.radius
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                    selected: trayMenu.isOpen
                }

                Image {
                    anchors.centerIn: parent
                    width: Theme.icon.size.md
                    height: Theme.icon.size.md
                    source: Tray.iconOf(icon.modelData)
                    sourceSize: Qt.size(width * 2, height * 2)
                    smooth: true
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton)
                            Tray.secondaryActivate(icon.modelData);
                        else if ((m.button === Qt.RightButton || Tray.menuOnly(icon.modelData)) && Tray.hasMenu(icon.modelData))
                            trayMenu.toggle();
                        else
                            Tray.activate(icon.modelData);
                    }
                    onWheel: w => Tray.scroll(icon.modelData, w.angleDelta.y / 120, false)
                }

                // Dev aid: BIFROST_DEV_OPEN_TRAY=<index> opens that item's menu at start.
                Timer {
                    running: Platform.env("BIFROST_DEV_OPEN_TRAY") !== "" && Number(Platform.env("BIFROST_DEV_OPEN_TRAY")) === icon.index
                    interval: 1500
                    onTriggered: trayMenu.open()
                }

                TrayMenu {
                    id: trayMenu

                    bar: widget.bar
                    anchorItem: icon
                    handle: Tray.menuOf(icon.modelData)
                }
            }
        }
    }
}
