import QtQuick
import qs.Core

// A card of SettingsNavRows (children), edge to edge like schema groups.
Item {
    id: list

    default property alias rows: column.data

    width: parent ? parent.width : 0
    height: column.implicitHeight + SettingsStyle.groupInset * 2

    SettingsGroupSurface {
        anchors.fill: parent
    }

    Column {
        id: column

        y: SettingsStyle.groupInset
        width: list.width
    }
}
