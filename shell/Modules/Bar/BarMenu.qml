import QtQuick
import qs.Core
import qs.Components.Motion
import qs.Components.Popup

// Base for every menu opened from the bar. The menu is drawn inside the bar
// window as an extension of the bar's glass (see MenuHost), not as a floating
// popup. Declare it next to its anchor; it moves itself into the bar's menu
// layer. Opening, closing, hover-leave, outside clicks and "one menu at a
// time" are handled here and in MenuHost for all menus alike.
//   BarMenu { id: m; bar: widget.bar; anchorItem: button; BText { … } }
//   m.click() from the anchor, m.toggle() / m.open() / m.close() from IPC;
//   `isOpen` for the anchor's selected state
// Menus open on hover over the anchor too (HoverIntent, bar.menus.openOnHover).
Item {
    id: menu

    property var bar: null
    // The item the menu opens from; it should expose `hovered` (see MenuHost).
    property Item anchorItem: null
    property real padding: Theme.space.sm
    // Menus that follow clicks take part in "one at a time" and grab focus;
    // hover details (system status) set this false.
    property bool grabFocus: true
    // Takes the keyboard at once, without a click first (the launcher).
    property bool exclusiveKeyboard: false
    property bool closeOnLeave: !grabFocus || Config.values.bar.menus.closeOnLeave
    // Hover details always open on hover; other menus follow the setting.
    // One setting for every bar menu, system status included.
    property bool openOnHover: Config.values.bar.menus.openOnHover
    property bool isOpen: false
    property bool openedByHover: false
    property real targetX: 0            // set by MenuHost

    property real contentWidth: contentArea.childrenRect.width
    property real contentHeight: contentArea.childrenRect.height
    // Extra room above the content, toward the bar (bar.menus.contentTopPadding).
    readonly property real topPadding: Math.max(0, padding + Config.values.bar.menus.contentTopPadding)
    // On a side bar the menu is turned with the bar (MenuHost works in bar
    // coordinates) and its content turned back upright: `face` is the menu
    // as seen on screen, with the extra padding on the side toward the bar.
    readonly property bool vertical: bar ? bar.vertical === true : false
    readonly property bool barOnLeft: vertical && bar.edge === "left"
    readonly property real faceWidth: Math.ceil(contentWidth + padding + (vertical ? topPadding : padding))
    readonly property real faceHeight: Math.ceil(contentHeight + (vertical ? padding * 2 : topPadding + padding))
    // Size in bar coordinates: along the bar × away from it.
    readonly property real menuWidth: vertical ? faceHeight : faceWidth
    readonly property real menuHeight: vertical ? faceWidth : faceHeight

    default property alias content: contentArea.data

    signal dismissed

    readonly property var host: bar ? bar.menuHost : null

    function open() {
        if (host)
            isOpen = true;
    }

    function close() {
        isOpen = false;
    }

    // A click on the anchor: opens, or closes a menu the click opened. A menu
    // hover just opened stays, so a click on arrival doesn't close it.
    function click() {
        hoverIntent.stop();
        if (isOpen && openedByHover)
            openedByHover = false;
        else
            toggle();
    }

    function toggle() {
        if (isOpen)
            close();
        else if (!PopupGroup.justDismissed(menu))
            open();
    }

    onIsOpenChanged: {
        if (isOpen) {
            PopupGroup.register(menu);
            host.show(menu);
        } else {
            openedByHover = false;
            PopupGroup.unregister(menu);
            if (host)
                host.hide(menu);
            dismissed();
        }
    }

    Component.onDestruction: if (isOpen && host)
        host.hide(menu)

    parent: host ? host.menuLayer : null
    x: targetX
    y: bar && bar.atBottom ? -menuHeight : (bar ? bar.barHeight : 0)
    width: menuWidth
    height: menuHeight
    enabled: isOpen
    visible: opacity > 0
    opacity: isOpen ? 1 : 0

    Behavior on opacity {
        BNumberAnimation {}
    }

    HoverIntent {
        id: hoverIntent

        hovered: menu.anchorItem !== null && menu.anchorItem.hovered === true
        isOpen: menu.isOpen
        active: menu.openOnHover && menu.host !== null
        onOpenRequested: {
            menu.open();
            menu.openedByHover = menu.isOpen;
        }
    }

    Item {
        id: face

        width: menu.faceWidth
        height: menu.faceHeight
        // Turned back by whole pixels (not around the centre) so text stays sharp.
        transform: [
            Rotation {
                angle: menu.vertical ? -90 : 0
            },
            Translate {
                y: menu.vertical ? menu.faceWidth : 0
            }
        ]

        Item {
            id: contentArea

            x: menu.barOnLeft ? menu.topPadding : menu.padding
            y: menu.vertical ? menu.padding : menu.topPadding
            width: menu.faceWidth - menu.padding - (menu.vertical ? menu.topPadding : menu.padding)
            height: menu.faceHeight - menu.padding - (menu.vertical ? menu.padding : menu.topPadding)
        }
    }
}
