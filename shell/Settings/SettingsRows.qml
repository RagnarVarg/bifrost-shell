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
    // Material rows: the surface they belong to (materials.<surface>.<prop>).
    readonly property string surface:materialRows && keys.length ? keys[0].split(".")[1] : ""
    property bool linked:materialRows && Config.get("materials.link") === true && surface !== "all" && (Config.get("materials.unlinked") || []).indexOf(surface) < 0
    // Editing a linked surface unlinks it (materials.unlinked). Its older own
    // values were hidden, so they are cleared: it still looks like All
    // surfaces apart from the change.
    function unlinkFor(key) {
        if (!linked)
            return;
        Config.set("materials.unlinked", (Config.get("materials.unlinked") || []).concat([surface]));
        Config.resetKeys(keys.filter(k => k !== key));
    }
    Connections {
        target:Config
        enabled:group.linked && group.visible
        function onSettingChanged(key, value) {
            if (group.keys.indexOf(key) >= 0 && value !== null && value !== undefined)
                Qt.callLater(group.unlinkFor, key);
        }
    }
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
                    enabled:dependencyMet && (!key.endsWith(".blur") || group.blurSupported)
                    fallback:group.materialRows && group.surfaceMaterial.effective ? group.surfaceMaterial.effective[key.split(".").pop()] : undefined
                    note:group.linked ? I18n.tr("Linked to All surfaces; changing it unlinks this surface") : key.endsWith(".blur") && group.blurStrength >= 0 ? I18n.tr("Compositor strength now: %1 % (the strongest surface with blur on)").arg(Math.round(group.blurStrength)) : ""
                }
            }
        }
    }
}
