import QtQuick
import qs.Core
import qs.Components.Glass
import qs.Components.Text

// A titled panel-glass card that holds one gallery section.
Item {
    id: section

    property string title: ""
    property string subtitle: ""
    property var material: Theme.materials.panel

    default property alias items: content.data

    implicitHeight: glass.height

    GlassSurface {
        id: glass

        width: parent.width
        height: column.implicitHeight + Theme.space.xxl * 2
        material: section.material

        Column {
            id: column

            x: Theme.space.xxl
            y: Theme.space.xxl
            width: parent.width - Theme.space.xxl * 2
            spacing: Theme.space.xl

            Column {
                width: parent.width
                spacing: Theme.space.xs

                BText {
                    text: section.title
                    role: "title"
                }

                BText {
                    visible: text !== ""
                    width: parent.width
                    text: section.subtitle
                    role: "caption"
                    tone: "muted"
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: content

                width: column.width
                height: childrenRect.height
            }
        }
    }
}
