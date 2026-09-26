import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Popup
import qs.Components.State
import qs.Components.Text
import qs.Services
import "../Modules/Dock/DockModel.js" as DockModel

// Right-click menu for a dock entry, drawn as Bifrost glass.
Item {
    id: menu

    property var item: null     // { key, app, pinned, windows }
    readonly property var pinned: Config.values.dock.pinned || []
    readonly property int index: item ? pinned.indexOf(item.key) : -1

    implicitWidth: list.width
    implicitHeight: list.implicitHeight
    signal closeRequested
    property bool showingInfo: false
    readonly property var windows: !item ? [] : Compositor.windows.filter(w => {
        const app = Apps.forAppId(w.appId);
        return app ? app.id === item.key : item.windows.some(old => old.id === w.id);
    })

    function close() { closeRequested(); }

    function setPinned(list) {
        Config.set("dock.pinned", list);
        // Keep context-menu ordering effective after a drag established ranks.
        if ((Config.values.dock.order || []).length)
            Config.set("dock.order", DockModel.rememberOrder(Config.values.dock.order,list));
    }

    component MenuRow: Item {
        id: row

        property string icon: ""
        property string text: ""
        property bool danger: false
        property bool keepOpen: false

        signal activated

        width: list.width
        height: Theme.control.height.md

        StateLayer {
            anchors.fill: parent
            radius: Theme.control.radius
            hovered: mouse.containsMouse
            pressed: mouse.pressed
        }

        BIcon {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            size: Theme.icon.size.sm
            color: row.danger ? Theme.color.danger : Theme.color.icon
        }

        BText {
            anchors.left: glyph.right
            anchors.leftMargin: Theme.space.sm
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            role: "label"
            tone: row.danger ? "danger" : "primary"
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                row.activated();
                if (!row.keepOpen) menu.close();
            }
        }
    }

    Column {
        id: list

        width: Theme.space.xxxl * 8

        BText {
            x: Theme.space.md
            width: parent.width - Theme.space.md * 2
            height: Theme.control.height.sm
            text: menu.item && menu.item.app ? menu.item.app.name : (menu.item ? menu.item.key.replace("window:", "") : "")
            role: "overline"
            tone: "muted"
            elide: Text.ElideRight
        }

        MenuRow {
            visible: menu.item !== null && menu.item.app !== null
            icon: "open"
            text: menu.windows.length && Apps.supportsNewWindow(menu.item.app) ? I18n.tr("Open new window") : I18n.tr("Open")
            onActivated: Apps.launchNewWindow(menu.item.app)
        }

        MenuRow {
            visible: menu.item !== null && menu.item.app !== null
            icon: "pin"
            text: menu.index >= 0 ? I18n.tr("Unpin from dock") : I18n.tr("Pin to dock")
            onActivated: menu.setPinned(menu.index >= 0 ? menu.pinned.filter(id => id !== menu.item.key) : menu.pinned.concat([menu.item.key]))
        }

        MenuRow {
            visible: menu.item !== null && menu.item.app !== null
            icon: "info"
            text: I18n.tr("App info")
            // Keep the shared menu open to show desktop-entry metadata.
            onActivated: menu.showingInfo = !menu.showingInfo
            keepOpen: true
        }

        BText {
            visible: menu.showingInfo && !!menu.item && !!menu.item.app
            width: parent.width - Theme.space.md * 2
            x: Theme.space.md
            text: menu.item && menu.item.app ? menu.item.app.name + "\n" + menu.item.key + "\n" + menu.item.app.comment : ""
            wrapMode: Text.Wrap
            role: "caption"
        }

        MenuRow {
            visible: menu.index > 0
            icon: "chevron-left"
            text: I18n.tr("Move left")
            onActivated: menu.setPinned(DockModel.moved(menu.pinned, menu.item.key, -1))
        }

        MenuRow {
            visible: menu.index >= 0 && menu.index < menu.pinned.length - 1
            icon: "chevron-right"
            text: I18n.tr("Move right")
            onActivated: menu.setPinned(DockModel.moved(menu.pinned, menu.item.key, 1))
        }

        BDivider {
            visible: menu.item !== null && menu.windows.length > 1
            width: parent.width
        }

        Repeater {
            model: menu.item && menu.windows.length > 1 ? menu.windows : []

            delegate: MenuRow {
                required property var modelData

                icon: "windows"
                text: modelData.title
                onActivated: Compositor.focusWindow(modelData.id)
            }
        }

        BDivider {
            visible: menu.item !== null && menu.windows.length > 0
            width: parent.width
        }

        MenuRow {
            visible: menu.item !== null && menu.windows.length > 0
            icon: "close"
            danger: true
            text: menu.item && menu.windows.length > 1 ? I18n.tr("Close all windows") : I18n.tr("Close window")
            onActivated: {
                for (const w of menu.windows)
                    Compositor.closeWindow(w.id);
            }
        }
    }
}
