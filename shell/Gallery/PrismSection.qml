import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Motion
import qs.Components.State
import qs.Components.Text

// Where the prism will be used: active workspace, selected rows, and how
// its strength reads at different intensities.
GallerySection {
    title: "Bifrost-prisma"
    subtitle: "Ljusbrytning i glaskanten: fyllningen lutar lätt mot tre dämpade nordljusfärger, en svag ljusdelning under överkanten och en kant som skiftar nyans runt om. Justera styrkan i panelen till höger."

    Column {
        width: parent.width
        spacing: Theme.space.xxl

        Column {
            spacing: Theme.space.sm

            BText {
                text: "Workspaces (aktiv = 3, har fönster = 1, 2, 5)"
                role: "overline"
                tone: "muted"
            }

            GlassSurface {
                id: strip

                property int current: 3

                material: Theme.materials.bar
                width: pills.implicitWidth + Theme.space.md * 2
                height: Theme.control.height.lg

                Row {
                    id: pills

                    anchors.centerIn: parent
                    spacing: Theme.space.xs

                    Repeater {
                        model: 7

                        delegate: Item {
                            id: pill

                            required property int index
                            readonly property int number: index + 1
                            readonly property bool isActive: strip.current === number
                            readonly property bool occupied: [1, 2, 5].indexOf(number) >= 0

                            width: isActive ? Theme.control.height.md * 1.8 : Theme.control.height.md
                            height: Theme.control.height.sm

                            Behavior on width {
                                BNumberAnimation {
                                    speed: "normal"
                                    curve: "emphasized"
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: height / 2
                                active: pill.isActive
                                hovered: mouse.containsMouse
                            }

                            BText {
                                anchors.centerIn: parent
                                text: pill.number
                                role: "label"
                                tone: pill.isActive ? "primary" : pill.occupied ? "muted" : "faint"
                            }

                            MouseArea {
                                id: mouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: strip.current = pill.number
                            }
                        }
                    }
                }
            }
        }

        Row {
            spacing: Theme.space.xxxl

            Repeater {
                model: [0.5, 1.0, 1.5]

                delegate: Column {
                    id: sample

                    required property real modelData

                    spacing: Theme.space.sm

                    BText {
                        text: "intensitet × " + sample.modelData.toFixed(1)
                        role: "mono"
                        tone: "muted"
                    }

                    GlassSurface {
                        material: Theme.materials.popover
                        width: Theme.control.height.lg * 7
                        height: list.implicitHeight + Theme.space.sm * 2

                        Column {
                            id: list

                            anchors.fill: parent
                            anchors.margins: Theme.space.sm

                            Repeater {
                                model: [{ t: "Wi-Fi", s: "Hemma 5G", i: "wifi", sel: false }, { t: "Bluetooth", s: "2 enheter", i: "bluetooth", sel: true }, { t: "Ljud", s: "Högtalare", i: "volume", sel: false }]

                                delegate: Item {
                                    id: rowItem

                                    required property var modelData

                                    width: list.width
                                    height: Theme.control.height.lg + Theme.space.sm

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: Theme.radius.md
                                        selected: rowItem.modelData.sel
                                        intensityScale: sample.modelData
                                        hovered: rowMouse.containsMouse
                                    }

                                    BListRow {
                                        anchors.fill: parent
                                        interactive: false
                                        icon: rowItem.modelData.i
                                        title: rowItem.modelData.t
                                        subtitle: rowItem.modelData.s
                                    }

                                    MouseArea {
                                        id: rowMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
