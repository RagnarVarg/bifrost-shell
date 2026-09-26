import QtQuick
import qs.Core
Item {
    implicitHeight:Theme.border.hairline
    opacity:SettingsStyle.dividerOpacity
    Rectangle { anchors.fill:parent; color:Theme.color.divider; visible:!SettingsStyle.dashed }
    Row {
        anchors.fill:parent
        visible:SettingsStyle.dashed
        spacing:Theme.space.xs
        clip:true
        Repeater {
            model:Math.ceil(parent.width/(Theme.space.sm+Theme.space.xs))
            Rectangle { width:Theme.space.sm; height:Theme.border.hairline; color:Theme.color.divider }
        }
    }
}
