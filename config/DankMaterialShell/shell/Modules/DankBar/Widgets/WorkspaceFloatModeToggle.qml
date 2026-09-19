import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property color tilingColor: Theme.widgetTextColor
    property color floatingColor: Theme.primary

    content: Component {
        Item {
            implicitWidth: icon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: WorkspaceFloatModeService.isFloating ? "open_in_new" : "grid_view"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: WorkspaceFloatModeService.isFloating ? root.floatingColor : root.tilingColor
            }
        }
    }

    MouseArea {
        z: 1
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
        }
        onClicked: {
            WorkspaceFloatModeService.toggle();
        }
    }
}
