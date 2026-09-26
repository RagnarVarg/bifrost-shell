import QtQuick
import qs.Core
import qs.Components.Glass
Item {
    GlassSurface {
        anchors.fill:parent
        visible:SettingsStyle.grouped && SettingsStyle.background
        material:SettingsStyle.material
    }
    Rectangle {
        anchors.fill:parent
        visible:!SettingsStyle.grouped
        color:Theme.color.controlFill
        radius:Theme.radius.lg
        border.width:Theme.border.hairline
        border.color:Theme.color.hairline
    }
}
