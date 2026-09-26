import QtQuick
import qs.Core
import qs.Components.Glass
import qs.Components.Text

// One glass sample with its name and key parameters.
GlassSurface {
    id: card

    property string name: ""
    property string note: ""

    width: Theme.space.xxxl * 9
    height: Theme.space.xxxl * 5

    Column {
        anchors.fill: parent
        anchors.margins: Theme.space.xl
        spacing: Theme.space.xs

        BText {
            text: card.name
            role: "overline"
            tone: "muted"
        }

        BText {
            width: parent.width
            text: card.note
            role: "caption"
            wrapMode: Text.WordWrap
            visible: text !== ""
        }
    }

    BText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space.xl
        role: "mono"
        tone: "faint"
        text: "opacity " + card.material.opacity.toFixed(2) + "  grain " + Number(card.material.grain).toFixed(3) + "  r " + Math.round(card.radius)
    }
}
