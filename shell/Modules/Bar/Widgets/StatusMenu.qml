import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar

// Base for the bar's status menus (Bluetooth, audio, VPN, network): a
// menu growing out of the bar under the icon, with a title row and optional
// header control.
BarMenu {
    id: menu

    property string title: ""
    default property alias body: column.data
    property alias header: headerSlot.data

    padding: Theme.space.md

    Column {
        id: column

        width: Theme.layout.controlCenterWidth - Theme.space.xl
        spacing: Theme.space.sm

        Item {
            width: parent.width
            height: Theme.control.height.md

            BText {
                anchors.verticalCenter: parent.verticalCenter
                text: menu.title
                role: "heading"
            }

            Item {
                id: headerSlot

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: childrenRect.width
                height: childrenRect.height
            }
        }
    }
}
