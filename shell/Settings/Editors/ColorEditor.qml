import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text

// Colour setting: a round colour dot with its hex value; clicking the dot
// opens the HSV picker, a hex field and quick picks from the theme palette.
// "Bifrost default" returns a nullable colour to the theme. The picker
// previews live: every drag step is written through Config, and both
// Settings and the shell restyle at once.
EditorBase {
    id: editor

    readonly property bool isNull: value === null || value === undefined || value === ""
    readonly property string shown: isNull ? String(inherited() || Theme.palette.accent || "") : value
    readonly property var picks: ["accent", "accentDeep", "silver", "success", "warning", "danger"].map(k => Theme.palette[k]).concat(Theme.prism.stops || [])
    property bool open: false

    implicitWidth: Theme.layout.settingsEditorWidth
    implicitHeight: top.height + (open ? Theme.space.md + panel.implicitHeight : 0)

    Row {
        id: top

        anchors.right: parent.right
        height: Theme.control.height.md
        spacing: Theme.space.md

        BChip {
            visible: editor.def.nullable === true
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Bifrost default")
            selected: editor.isNull
            onClicked: editor.set(null)
        }

        BText {
            anchors.verticalCenter: parent.verticalCenter
            text: editor.shown.toUpperCase()
            role: "mono"
            tone: editor.isNull ? "faint" : "muted"
        }

        Item {
            id: dot

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.control.height.sm
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: editor.shown || "transparent"
                border.width: editor.open ? Theme.border.focus : Theme.border.hairline
                border.color: editor.open ? Theme.color.focus : Theme.color.innerBorder
            }

            StateLayer {
                anchors.fill: parent
                radius: width / 2
                hovered: dotMouse.containsMouse
                focused: dot.activeFocus
            }

            activeFocusOnTab: true
            Keys.onSpacePressed: editor.open = !editor.open

            MouseArea {
                id: dotMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: editor.open = !editor.open
            }
        }
    }

    Column {
        id: panel

        anchors.top: top.bottom
        anchors.topMargin: Theme.space.md
        anchors.right: parent.right
        width: Math.min(parent.width, Theme.layout.settingsEditorWidth)
        spacing: Theme.space.md
        visible: editor.open

        BColorPicker {
            width: parent.width
            color: editor.shown || Theme.palette.accent
            onPicked: hex => editor.set(hex)
        }

        BTextField {
            width: parent.width
            icon: "palette"
            text: editor.shown
            onAccepted: t => {
                const h = (t.startsWith("#") ? t : "#" + t).toUpperCase();
                if (/^#[0-9A-F]{6}$/.test(h))
                    editor.set(h);
            }
        }

        Flow {
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
}
