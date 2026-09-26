import QtQuick
import qs.Core
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Dropdown. model: strings or { value, label } objects. Emits activated(value);
// `currentValue` is not changed internally so it can stay bound to Config.
// The list opens in a popover glass on top of the window (reparented to the
// window's root item so it is never clipped by scroll views).
Item {
    id: root

    property var model: []
    property var currentValue: null
    property string placeholder: ""
    property bool searchable: false

    signal activated(var value)

    readonly property var items: (model || []).map(m => typeof m === "object" && m !== null ? m : { value: m, label: String(m) })
    readonly property var current: items.find(i => JSON.stringify(i.value) === JSON.stringify(currentValue)) || null
    property bool opened: false
    property string filter: ""

    implicitHeight: Theme.control.height.md
    implicitWidth: Theme.layout.editorWidth
    opacity: enabled ? 1 : Theme.opacity.disabled
    activeFocusOnTab: true

    function hostItem() {
        let p = root;
        while (p.parent)
            p = p.parent;
        return p;
    }

    function open() {
        const host = hostItem();
        overlay.parent = host;
        filter = "";
        const below = root.mapToItem(host, 0, root.height + Theme.space.xs);
        const h = popup.height;
        popup.x = Math.min(below.x, host.width - popup.width - Theme.space.md);
        popup.y = below.y + h > host.height - Theme.space.md ? root.mapToItem(host, 0, 0).y - h - Theme.space.xs : below.y;
        opened = true;
        if (searchable)
            search.forceActiveFocus();
    }

    function close() {
        opened = false;
    }

    function choose(value) {
        close();
        activated(value);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.control.radius
        color: Theme.color.controlFill
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.control.radius
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        selected: root.opened
        focused: root.activeFocus
    }

    BText {
        anchors.left: parent.left
        anchors.leftMargin: Theme.control.paddingX
        anchors.right: chevron.left
        anchors.rightMargin: Theme.space.sm
        anchors.verticalCenter: parent.verticalCenter
        text: root.current ? root.current.label : root.placeholder
        tone: root.current ? "primary" : "faint"
        role: "label"
        elide: Text.ElideRight
    }

    BIcon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        size: Theme.icon.size.sm
        color: Theme.color.iconMuted
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened ? root.close() : root.open()
    }

    Keys.onSpacePressed: open()
    Keys.onReturnPressed: open()

    Item {
        id: overlay

        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        visible: root.opened
        z: 1000

        // Click outside closes.
        MouseArea {
            anchors.fill: parent
            onPressed: root.close()
        }

        GlassSurface {
            id: popup

            material: Theme.materials.popover
            width: Math.max(root.width, Theme.layout.editorWidth * 0.75)
            height: Math.min(Theme.layout.popupMaxHeight, column.implicitHeight + Theme.space.sm * 2)

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: column

                anchors.fill: parent
                anchors.margins: Theme.space.sm
                spacing: Theme.space.xs

                BTextField {
                    id: search

                    visible: root.searchable
                    width: parent.width
                    icon: "search"
                    placeholder: I18n.tr("Filter")
                    onTextChanged: root.filter = text.toLowerCase()
                    Keys.onEscapePressed: root.close()
                }

                ListView {
                    id: list

                    width: parent.width
                    height: Math.min(contentHeight, Theme.layout.popupMaxHeight - (search.visible ? search.height + column.spacing : 0) - Theme.space.sm * 2)
                    implicitHeight: contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.items.filter(i => !root.filter || i.label.toLowerCase().indexOf(root.filter) >= 0)

                    delegate: Item {
                        id: option

                        required property var modelData
                        readonly property bool isCurrent: root.current !== null && JSON.stringify(modelData.value) === JSON.stringify(root.current.value)

                        enabled: modelData.enabled !== false
                        opacity: enabled ? 1 : Theme.opacity.disabled
                        width: list.width
                        height: Theme.control.height.md

                        StateLayer {
                            anchors.fill: parent
                            radius: Theme.control.radius
                            hovered: optionMouse.containsMouse
                            pressed: optionMouse.pressed
                            selected: option.isCurrent
                        }

                        BText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.space.lg
                            anchors.right: check.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: option.modelData.label
                            role: "label"
                            font.family: option.modelData.family || Theme.typography.label.family
                            elide: Text.ElideRight
                        }

                        BIcon {
                            id: check

                            visible: option.isCurrent
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.space.md
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: Theme.icon.size.sm
                        }

                        MouseArea {
                            id: optionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choose(option.modelData.value)
                        }
                    }

                    BScrollIndicator {
                        flickable: list
                    }
                }
            }
        }
    }
}
