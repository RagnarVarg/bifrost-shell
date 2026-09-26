import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.State
import qs.Components.Text

// The approved standard glass (themes/_base.json → glass + materials) in the
// situations it will be used in: a panel with content, glass on glass, and a
// bar strip.
GallerySection {
    title: "Bifrost-glas"
    subtitle: "Standardmaterialet: tjockt och klart. Djupet kommer från ton som mörknar nedåt, en klar överkant och en tunn silverkant — inte från frost — så skrivbordet syns igenom."

    Flow {
        width: parent.width
        spacing: Theme.space.xxxl

        // Panel with real content
        GlassSurface {
            material: Theme.materials.panel
            width: Theme.space.xxxl * 12
            height: Theme.space.xxxl * 9

            Column {
                anchors.fill: parent
                anchors.margins: Theme.space.xxl
                spacing: Theme.space.lg

                BText {
                    text: "panel"
                    role: "overline"
                    tone: "muted"
                }

                BText {
                    text: "Kontrollcenter"
                    role: "title"
                }

                BText {
                    width: parent.width
                    text: "Bakgrunden ska synas genom glaset utan att texten tappar kontrast."
                    role: "body"
                    tone: "muted"
                    wrapMode: Text.WordWrap
                }

                BListRow {
                    width: parent.width
                    icon: "wifi"
                    title: "Wi-Fi"
                    subtitle: "Hemma 5G"
                    selected: true

                    BToggle {
                        checked: true
                        onToggled: c => checked = c
                    }
                }

                BSlider {
                    width: parent.width
                    value: 0.7
                    onMoved: v => value = v
                }
            }
        }

        // Glass on glass
        GlassSurface {
            material: Theme.materials.panel
            width: Theme.space.xxxl * 12
            height: Theme.space.xxxl * 9

            BText {
                x: Theme.space.xxl
                y: Theme.space.xxl
                text: "glas på glas: popover över panel"
                role: "overline"
                tone: "muted"
            }

            GlassSurface {
                material: Theme.materials.popover
                x: Theme.space.xxxl * 2
                y: Theme.space.xxxl * 2.5
                width: Theme.space.xxxl * 8
                height: menu.implicitHeight + Theme.space.sm * 2

                Column {
                    id: menu

                    property int current: 1

                    anchors.fill: parent
                    anchors.margins: Theme.space.sm

                    Repeater {
                        model: [["display", "Skärm"], ["volume", "Ljud"], ["bell", "Notiser"], ["palette", "Utseende"]]

                        delegate: BListRow {
                            required property int index
                            required property var modelData

                            width: menu.width
                            icon: modelData[0]
                            title: modelData[1]
                            selected: menu.current === index
                            onClicked: menu.current = index
                        }
                    }
                }
            }
        }

        // Bar strip
        Column {
            spacing: Theme.space.xxxl

            GlassSurface {
                id: bar

                property int current: 2

                material: Theme.materials.bar
                width: Theme.space.xxxl * 18
                height: Theme.control.height.lg + Theme.space.sm * 2

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xs

                    Repeater {
                        model: 5

                        delegate: Item {
                            id: ws

                            required property int index

                            width: bar.current === index ? Theme.control.height.md * 1.8 : Theme.control.height.md
                            height: Theme.control.height.sm

                            StateLayer {
                                anchors.fill: parent
                                radius: height / 2
                                active: bar.current === ws.index
                                hovered: wsMouse.containsMouse
                            }

                            BText {
                                anchors.centerIn: parent
                                text: ws.index + 1
                                role: "label"
                                tone: bar.current === ws.index ? "primary" : "muted"
                            }

                            MouseArea {
                                id: wsMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: bar.current = ws.index
                            }
                        }
                    }
                }

                BText {
                    anchors.centerIn: parent
                    text: "21:47"
                    role: "readout"
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.xxs

                    BIconButton {
                        icon: "wifi"
                        size: "sm"
                    }

                    BIconButton {
                        icon: "volume"
                        size: "sm"
                    }

                    BIconButton {
                        icon: "tune"
                        size: "sm"
                    }
                }
            }

            GlassSurface {
                material: Theme.materials.osd
                width: Theme.space.xxxl * 8
                height: Theme.control.height.lg + Theme.space.lg * 2

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.space.lg

                    BText {
                        text: "osd"
                        role: "overline"
                        tone: "muted"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BSlider {
                        width: Theme.space.xxxl * 5
                        value: 0.45
                        onMoved: v => value = v
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            BText {
                width: Theme.space.xxxl * 18
                text: "glass: depth " + Theme.glass.depth + " · highlight " + Theme.glass.highlight + " · sheen " + Theme.glass.sheen + " · grain " + Theme.glass.grain + " · rim " + Theme.opacity.innerBorder
                role: "mono"
                tone: "faint"
                wrapMode: Text.WordWrap
            }
        }
    }
}
