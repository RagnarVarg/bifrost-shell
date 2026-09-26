import QtQuick
import qs.Compat
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Services

// One notification: app icon/name, time, summary, body, image, actions.
// Used by popups (on popover glass) and the notification center.
Item {
    id: card

    property var item: null
    property bool popup: false

    signal closeRequested

    implicitHeight: column.implicitHeight + Theme.space.lg * 2

    // Senders often pass a themed icon as the image (notify-send -i): show it
    // as the app icon; only real images get the large thumbnail.
    readonly property bool imageIsIcon: item !== null && item.image.startsWith("image://icon/")
    readonly property string iconSource: !item ? "" : item.appIcon ? Platform.iconPath(item.appIcon, "dialog-information") : imageIsIcon ? Platform.iconPath(item.image, "dialog-information") : Platform.iconPath("", "dialog-information")

    function ago(t) {
        const s = Math.max(0, (Date.now() - t.getTime()) / 1000);
        return s < 60 ? I18n.tr("now") : s < 3600 ? I18n.tr("%1 min").arg(Math.floor(s / 60)) : I18n.tr("%1 h").arg(Math.floor(s / 3600));
    }

    Rectangle {
        anchors.fill: parent
        visible: !card.popup
        radius: Theme.radius.lg
        color: Theme.color.controlFill
        border.width: Theme.border.hairline
        border.color: card.item && card.item.critical ? Qt.alpha(Theme.color.danger, Math.min(1, Theme.opacity.innerBorder * 3)) : Theme.color.hairline
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.radius.lg
        hovered: hover.hovered
    }

    HoverHandler {
        id: hover
    }

    Column {
        id: column

        x: Theme.space.lg
        y: Theme.space.lg
        width: parent.width - Theme.space.lg * 2
        spacing: Theme.space.xs

        Item {
            width: parent.width
            height: Theme.icon.size.md

            Image {
                id: appIcon

                width: Theme.icon.size.md
                height: width
                source: card.iconSource
                sourceSize: Qt.size(width * 2, height * 2)
            }

            BText {
                anchors.left: appIcon.right
                anchors.leftMargin: Theme.space.sm
                anchors.right: time.left
                anchors.verticalCenter: parent.verticalCenter
                text: card.item ? card.item.appName : ""
                role: "caption"
                tone: card.item && card.item.critical ? "danger" : "muted"
                elide: Text.ElideRight
            }

            BText {
                id: time

                anchors.right: close.left
                anchors.rightMargin: Theme.space.xs
                anchors.verticalCenter: parent.verticalCenter
                text: card.item ? card.ago(card.item.time) : ""
                role: "mono"
                tone: "faint"
            }

            BIconButton {
                id: close

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                size: "sm"
                opacity: hover.hovered ? 1 : 0
                onClicked: card.closeRequested()
            }
        }

        Row {
            width: parent.width
            spacing: Theme.space.md

            Column {
                width: parent.width - (image.visible ? image.width + Theme.space.md : 0)
                spacing: Theme.space.xxs

                BText {
                    width: parent.width
                    text: card.item ? card.item.summary : ""
                    role: "label"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                BText {
                    width: parent.width
                    visible: text !== ""
                    text: card.item ? card.item.body.replace(/<[^>]*>/g, "") : ""
                    role: "body"
                    tone: "muted"
                    wrapMode: Text.Wrap
                    maximumLineCount: card.popup ? 3 : 6
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            Image {
                id: image

                visible: card.item !== null && card.item.image !== "" && !card.imageIsIcon
                width: Theme.control.height.lg + Theme.space.md
                height: width
                source: card.item ? card.item.image : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width * 2, height * 2)
            }
        }

        Flow {
            visible: card.item !== null && card.item.actions.length > 0
            width: parent.width
            spacing: Theme.space.sm
            topPadding: Theme.space.xs

            Repeater {
                model: card.item ? card.item.actions : []

                delegate: BButton {
                    required property var modelData

                    text: modelData.text
                    size: "sm"
                    onClicked: {
                        modelData.invoke();
                        Notify.hidePopup(card.item.id);
                    }
                }
            }
        }
    }
}
