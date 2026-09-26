import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.State

// Colour setting: swatch (click opens the HSV picker), hex field, quick picks
// from the theme palette and "Bifrost default" for nullable colours. The
// picker previews live: every drag step is written through Config, and both
// Settings and the shell restyle at once.
EditorBase {
    id: editor

    readonly property bool isNull: value === null || value === undefined || value === ""
    readonly property string shown: isNull ? String(inherited() || Theme.palette.accent || "") : value
    readonly property var picks: ["accent", "accentDeep", "silver", "success", "warning", "danger"].map(k => Theme.palette[k]).concat(Theme.prism.stops || [])
    property bool open: false

    implicitWidth: Theme.layout.editorWidth
    implicitHeight: top.height + Theme.space.sm + (open ? picker.implicitHeight + Theme.space.md : 0) + quick.height

    Flow {
        id: top

        anchors.right: parent.right
        width: parent.width
        spacing: Theme.space.sm

        BChip {
            visible: editor.def.nullable === true
            text: I18n.tr("Bifrost default")
            selected: editor.isNull
            onClicked: editor.set(null)
        }

        Item {
            width: Theme.control.height.md
            height: Theme.control.height.md

            Rectangle {
                anchors.fill: parent
                radius: Theme.control.radius
                color: editor.shown || "transparent"
                border.width: editor.open ? Theme.border.focus : Theme.border.hairline
                border.color: editor.open ? Theme.color.focus : Theme.color.innerBorder
            }

            StateLayer {
                anchors.fill: parent
                radius: Theme.control.radius
                hovered: swatchMouse.containsMouse
            }

            MouseArea {
                id: swatchMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: editor.open = !editor.open
            }
        }

        BTextField {
            width: Theme.space.xxxl * 4
            text: editor.shown
            onAccepted: t => {
                const h = (t.startsWith("#") ? t : "#" + t).toUpperCase();
                if (/^#[0-9A-F]{6}$/.test(h))
                    editor.set(h);
            }
        }
    }

    BColorPicker {
        id: picker

        anchors.top: top.bottom
        anchors.topMargin: Theme.space.md
        anchors.right: parent.right
        width: Math.min(parent.width, Theme.layout.editorWidth)
        visible: editor.open
        color: editor.shown || Theme.palette.accent
        onPicked: hex => editor.set(hex)
    }

    Flow {
        id: quick

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Theme.space.xs

        Repeater {
            model: editor.picks

            delegate: Item {
                id: pick

                required property string modelData

                width: Theme.control.height.sm
                height: Theme.control.height.sm

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.space.xxs
                    radius: width / 2
                    color: pick.modelData
                    border.width: Theme.border.hairline
                    border.color: Theme.color.innerBorder
                }

                StateLayer {
                    anchors.fill: parent
                    radius: width / 2
                    hovered: pickMouse.containsMouse
                    selected: !editor.isNull && String(editor.value).toUpperCase() === pick.modelData.toUpperCase()
                }

                MouseArea {
                    id: pickMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editor.set(pick.modelData)
                }
            }
        }
    }
}
