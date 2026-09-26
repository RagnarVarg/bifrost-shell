import QtQuick
import qs.Core
import qs.Services
import qs.Shared
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text
import qs.Modules.Bar

BarWidget {
    id: widget
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarButton {
        id: button
        anchors.fill: parent
        vertical: widget.vertical
        selected: menu.isOpen
        onClicked: menu.click()
        BIcon { color: Theme.color.text; name: Media.playing ? "play" : "music" }
        BText {
            visible: !widget.vertical && Media.available
            width: Math.min(implicitWidth, Theme.layout.editorWidth)
            text: Media.title + (Media.artist ? " · " + Media.artist : "")
            elide: Text.ElideRight
            role: "label"
        }
    }

    BarMenu {
        id: menu
        bar: widget.bar
        anchorItem: button
        onIsOpenChanged: isOpen ? Media.retain() : Media.release()
        Component.onDestruction: if (isOpen) Media.release()
        Column {
            width: Theme.layout.clockMenuWidth
            spacing: Theme.space.md
            MediaPanel { width: parent.width; visible: Media.available }
            BText {
                width: parent.width
                visible: !Media.available
                text: I18n.tr("No media player")
                role: "label"
                wrapMode: Text.Wrap
            }
        }
    }
}
