import QtQuick
import qs.Core

// Shared schema-row container: one rounded glass card, rows edge to edge
// split by hairlines that start at the rows' text.
Item {
    id:group
    property var keys:[]
    width:parent ? parent.width : 0
    height:rowsColumn.implicitHeight+(SettingsStyle.grouped ? SettingsStyle.groupInset*2 : 0)
    function rowFor(key) {
        for(let i=0;i<rows.count;i++){ const r=rows.itemAt(i); if(r && r.key===key) return r; }
        return null;
    }
    SettingsGroupSurface { anchors.fill:parent; visible:SettingsStyle.grouped }
    Column {
        id:rowsColumn
        y:SettingsStyle.grouped ? SettingsStyle.groupInset : 0
        width:group.width
        spacing:SettingsStyle.rowSpacing
        Repeater {
            id:rows
            model:group.keys
            delegate:Item {
                required property string modelData
                required property int index
                readonly property string key:modelData
                width:rowsColumn.width
                height:row.implicitHeight
                SettingsGroupSurface { anchors.fill:parent; visible:!SettingsStyle.grouped }
                SettingsDivider {
                    visible:SettingsStyle.separators && index>0
                    x:SettingsStyle.separatorInset
                    y:-SettingsStyle.rowSpacing/2
                    width:Math.max(0,parent.width-x)
                }
                SettingRow {
                    id:row
                    key:parent.modelData
                    enabled:dependencyMet
                }
            }
        }
    }
}
