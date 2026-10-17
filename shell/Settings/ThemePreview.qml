import QtQuick
import qs.Core
import qs.Components.Text

// A miniature Bifrost desktop drawn in a catalog theme's own Base16 colours,
// mapped the same way theme_catalog.py maps them (base 00, surface 01,
// raised 02, text 05/04, accent 0D, success 0B, warning 0A, danger 08).
// Everything is measured in fractions of the preview, so it scales with the card.
Rectangle {
    id: preview

    required property var colors
    readonly property real u: height / 100

    function c(key) { return colors[key] || "transparent"; }

    implicitHeight: width / Theme.layout.themePreviewAspect
    radius: Theme.radius.lg
    color: c("00")
    border.width: Theme.border.hairline
    border.color: c("02")
    clip: true

    // Panel: workspaces, clock, status dots
    Rectangle {
        id: panel
        x: 0; y: 0
        width: parent.width
        height: 11 * preview.u
        radius: preview.radius
        color: preview.c("01")

        // Square off the bottom corners; only the top follows the preview's rounding.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height / 2
            color: parent.color
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 3 * preview.u
            spacing: 1.6 * preview.u
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: index === 0 ? 6 * preview.u : 2.6 * preview.u
                    height: 2.6 * preview.u
                    radius: height / 2
                    color: index === 0 ? preview.c("0D") : preview.c("03")
                }
            }
        }
        BText {
            anchors.centerIn: parent
            text: "12:34"
            color: preview.c("05")
            font.pixelSize: 6 * preview.u
            font.weight: Font.DemiBold
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 3 * preview.u
            spacing: 1.6 * preview.u
            Repeater {
                model: ["0B", "0A", "08"]
                Rectangle {
                    required property string modelData
                    width: 2.6 * preview.u
                    height: width
                    radius: width / 2
                    color: preview.c(modelData)
                }
            }
        }
    }

    // Window: title bar, text, buttons
    Rectangle {
        id: window
        x: 5 * preview.u
        y: panel.height + 6 * preview.u
        width: parent.width * 0.56
        height: parent.height - y - 18 * preview.u
        radius: Theme.radius.md
        color: preview.c("01")
        border.width: Theme.border.hairline
        border.color: preview.c("02")
        clip: true

        Rectangle {
            id: titleBar
            width: parent.width
            height: 9 * preview.u
            color: preview.c("02")
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 3 * preview.u
                spacing: 1.4 * preview.u
                Repeater {
                    model: ["08", "0A", "0B"]
                    Rectangle {
                        required property string modelData
                        width: 2.4 * preview.u
                        height: width
                        radius: width / 2
                        color: preview.c(modelData)
                    }
                }
            }
        }
        Column {
            x: 4 * preview.u
            y: titleBar.height + 4 * preview.u
            width: parent.width - 8 * preview.u
            spacing: 2.6 * preview.u
            BText {
                text: "Bifrost"
                color: preview.c("05")
                font.pixelSize: 7 * preview.u
                font.weight: Font.DemiBold
            }
            Repeater {
                model: [0.92, 0.74, 0.84]
                Rectangle {
                    required property real modelData
                    required property int index
                    width: parent.width * modelData
                    height: 2.2 * preview.u
                    radius: height / 2
                    color: index === 0 ? preview.c("04") : preview.c("03")
                }
            }
            Row {
                spacing: 2 * preview.u
                Rectangle {
                    width: 18 * preview.u
                    height: 7 * preview.u
                    radius: height / 2
                    color: preview.c("0D")
                    BText {
                        anchors.centerIn: parent
                        text: "OK"
                        color: preview.c("00")
                        font.pixelSize: 4 * preview.u
                        font.weight: Font.DemiBold
                    }
                }
                Rectangle {
                    width: 18 * preview.u
                    height: 7 * preview.u
                    radius: height / 2
                    color: preview.c("02")
                }
            }
        }
    }

    // Menu / control center with a highlighted row and a toggle
    Rectangle {
        x: window.x + window.width + 5 * preview.u
        y: window.y
        width: parent.width - x - 5 * preview.u
        height: window.height * 0.82
        radius: Theme.radius.md
        color: preview.c("02")
        clip: true

        Column {
            x: 3 * preview.u
            y: 3 * preview.u
            width: parent.width - 6 * preview.u
            spacing: 2 * preview.u
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: parent.width
                    height: 7 * preview.u
                    radius: Theme.radius.sm
                    color: index === 1 ? preview.c("03") : "transparent"
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2 * preview.u
                        width: parent.width * 0.5
                        height: 2 * preview.u
                        radius: height / 2
                        color: index === 1 ? preview.c("05") : preview.c("04")
                    }
                    Rectangle {
                        visible: index === 0
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 2 * preview.u
                        width: 8 * preview.u
                        height: 4.4 * preview.u
                        radius: height / 2
                        color: preview.c("0D")
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 0.7 * preview.u
                            width: 3 * preview.u
                            height: width
                            radius: width / 2
                            color: preview.c("00")
                        }
                    }
                }
            }
        }
    }

    // Dock
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3 * preview.u
        width: dockRow.width + 4 * preview.u
        height: 10 * preview.u
        radius: Theme.radius.md
        color: preview.c("01")
        border.width: Theme.border.hairline
        border.color: preview.c("02")
        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 2 * preview.u
            Repeater {
                model: ["0D", "0E", "0C", "0B", "09", "08"]
                Rectangle {
                    required property string modelData
                    width: 6 * preview.u
                    height: width
                    radius: Theme.radius.sm
                    color: preview.c(modelData)
                }
            }
        }
    }
}
