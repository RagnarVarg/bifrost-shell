import QtQuick
import qs.Core

// Shared schema-row container: one glass group or one box per row.
Item {
    id:group
    property var keys:[]
    property bool materialRows:false
    property var surfaceMaterial:SettingsStyle.material
    property bool blurSupported:true
    property real blurStrength:-1
    property bool linked:materialRows && Config.get("materials.link") === true
    width:parent ? parent.width : 0
    height:rowsColumn.implicitHeight+(SettingsStyle.grouped ? SettingsStyle.innerPadding*2 : 0)
    function rowFor(key) {
        for(let i=0;i<rows.count;i++){ const r=rows.itemAt(i); if(r && r.key===key) return r; }
        return null;
    }
    SettingsGroupSurface { anchors.fill:parent; visible:SettingsStyle.grouped }
    Column {
        id:rowsColumn
        x:SettingsStyle.grouped ? SettingsStyle.innerPadding : 0
        y:x
        width:Math.max(0,group.width-x*2)
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
                    width:Math.max(0,parent.width-x*2)
                }
                SettingRow {
                    id:row
                    key:parent.modelData
                    linked:group.linked
                    enabled:dependencyMet && !group.linked && (!key.endsWith(".blur") || group.blurSupported)
                    fallback:group.materialRows && group.surfaceMaterial.effective ? group.surfaceMaterial.effective[key.split(".").pop()] : undefined
                    note:group.linked ? I18n.tr("Linked to All surfaces") : key.endsWith(".blur") && group.blurStrength >= 0 ? I18n.tr("Compositor strength now: %1 % (the strongest surface with blur on)").arg(Math.round(group.blurStrength)) : ""
                }
            }
        }
    }
}
