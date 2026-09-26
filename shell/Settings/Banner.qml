import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text

// Inline notice. tone: info | warning | danger. Optional action button.
Item {
    id: banner

    property string tone: "info"
    property string text: ""
    property string actionText: ""

    signal action

    readonly property color toneColor: tone === "warning" ? Theme.color.warning : tone === "danger" ? Theme.color.danger : Theme.color.accent

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.control.height.lg, label.implicitHeight + Theme.space.lg * 2)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.md
        color: Qt.alpha(banner.toneColor, Theme.opacity.stateHover)
        border.width: Theme.border.hairline
        border.color: Qt.alpha(banner.toneColor, Math.min(1, Theme.opacity.innerBorder * 2))
    }

    BIcon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        name: banner.tone === "info" ? "info" : "warning"
        size: Theme.icon.size.md
        color: banner.toneColor
    }

    BText {
        id: label

        anchors.left: glyph.right
        anchors.leftMargin: Theme.space.md
        anchors.right: button.visible ? button.left : parent.right
        anchors.rightMargin: Theme.space.lg
        anchors.verticalCenter: parent.verticalCenter
        text: banner.text
        role: "body"
        wrapMode: Text.WordWrap
    }

    BButton {
        id: button

        visible: banner.actionText !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        size: "sm"
        text: banner.actionText
        onClicked: banner.action()
    }
}
