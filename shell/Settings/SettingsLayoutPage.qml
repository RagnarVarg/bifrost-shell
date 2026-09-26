import QtQuick
import qs.Core
import qs.Components.Text
PageBase {
    title:I18n.tr("Settings layout")
    SettingsRows { keys:["settingsUI.layout"] }
    Column {
        visible:SettingsStyle.grouped
        width:parent.width
        spacing:SettingsStyle.groupSpacing
        BText { text:I18n.tr("Grouped appearance"); role:"heading" }
        BText {
            width:parent.width
            text:I18n.tr("Groups use the shared glass material. Empty values inherit All surfaces or the theme. Background blur is shared by the Settings window, not applied separately to each group.")
            role:"caption"; tone:"muted"; wrapMode:Text.Wrap
        }
        SettingsRows { keys:["settingsUI.grouped.background", "materials.link"] }
        SettingsRows {
            materialRows:true
            keys:["transparency","blur","tint","border","borderWidth","borderOpacity","borderColor","radius","shadow","glow"].map(p=>"materials.settingsGroups."+p)
        }
        BText { text:I18n.tr("Grouped layout"); role:"heading" }
        SettingsRows {
            keys:(Schema.section("settingsUI") ? Schema.section("settingsUI").settings : []).map(d=>d.key).filter(k=>k!=="settingsUI.layout" && k!=="settingsUI.grouped.background")
        }
    }
}
