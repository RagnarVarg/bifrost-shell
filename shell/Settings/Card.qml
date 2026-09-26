import QtQuick
import qs.Core

// Shared group/card styling for every custom Settings page.
Item {
    id:card
    default property alias content:inner.data
    property real padding:SettingsStyle.innerPadding
    width:parent ? parent.width : 0
    height:inner.implicitHeight+padding*2
    readonly property var settingRows: Array.from(inner.children).filter(c => c.visible && c.settingRow === true)
    SettingsGroupSurface { anchors.fill:parent; visible:SettingsStyle.grouped || !card.settingRows.length }
    Column {
        id:inner
        x:card.padding; y:card.padding
        width:Math.max(0,card.width-card.padding*2)
        spacing:SettingsStyle.rowSpacing
    }
    Repeater {
        model:card.settingRows
        SettingsDivider {
            required property var modelData
            required property int index
            visible:SettingsStyle.separators && index>0
            x:card.padding+SettingsStyle.separatorInset
            y:card.padding+modelData.y-SettingsStyle.rowSpacing/2
            width:Math.max(0,inner.width-SettingsStyle.separatorInset*2)
        }
    }
}
