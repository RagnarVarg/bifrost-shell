import QtQuick
import qs.Core
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Single-line text input with optional leading icon.
Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string icon: ""
    // md: forms; lg: prominent search (launcher)
    property string size: "md"
    property bool password: false
    readonly property var type: size === "lg" ? Theme.typography.heading : Theme.typography.body
    property alias input: input

    signal accepted(string text)
    // Every key press before the field handles it; set event.accepted to consume.
    signal keyPressed(var event)

    implicitHeight: size === "lg" ? Theme.control.height.lg + Theme.space.md : Theme.control.field.height
    implicitWidth: Theme.control.field.height * 8

    Rectangle {
        anchors.fill: parent
        radius: Theme.control.field.radius
        color: Theme.color.fieldFill
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.control.field.radius
        hovered: mouse.containsMouse && !input.activeFocus
        focused: input.activeFocus
    }

    BIcon {
        id: leading

        visible: root.icon !== ""
        name: root.icon
        size: root.size === "lg" ? Theme.icon.size.md : Theme.icon.size.sm
        color: Theme.color.iconMuted
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
    }

    TextInput {
        id: input

        anchors.left: leading.visible ? leading.right : parent.left
        anchors.leftMargin: leading.visible ? Theme.space.md : Theme.space.lg
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.color.text
        selectionColor: Qt.alpha(Theme.color.accent, Theme.opacity.stateActive)
        selectedTextColor: Theme.color.text
        font.family: root.type.family
        font.pixelSize: root.type.size
        font.weight: root.type.weight
        clip: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        onAccepted: root.accepted(text)
        Keys.onPressed: e => root.keyPressed(e)

        BText {
            anchors.fill: parent
            visible: input.text === "" && !input.activeFocus
            text: root.placeholder
            role: root.size === "lg" ? "heading" : "body"
            tone: "faint"
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onPressed: e => {
            input.forceActiveFocus();
            e.accepted = false;
        }
    }
}
