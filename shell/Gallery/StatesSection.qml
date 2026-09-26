import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// All interaction states side by side, plus interactive ones.
GallerySection {
    title: "States"
    subtitle: "normal · hover · pressed · selected · active · focus. Selected, active och focus använder Bifrost-prismat; hover och pressed är neutrala."

    Column {
        width: parent.width
        spacing: Theme.space.xxl

        Row {
            spacing: Theme.space.xl

            Repeater {
                model: ["normal", "hover", "pressed", "selected", "active", "focus"]

                delegate: Column {
                    id: tile

                    required property string modelData

                    spacing: Theme.space.sm

                    Item {
                        width: Theme.control.height.lg * 4
                        height: Theme.control.height.lg * 1.5

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.control.radius
                            color: Theme.color.controlFill
                        }

                        StateLayer {
                            anchors.fill: parent
                            hovered: tile.modelData === "hover"
                            pressed: tile.modelData === "pressed"
                            selected: tile.modelData === "selected"
                            active: tile.modelData === "active"
                            focused: tile.modelData === "focus"
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.space.sm

                            BIcon {
                                name: "layers"
                                size: Theme.icon.size.sm
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            BText {
                                text: "Objekt"
                                role: "label"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    BText {
                        text: tile.modelData
                        role: "mono"
                        tone: "muted"
                    }
                }
            }
        }

        Column {
            spacing: Theme.space.sm

            BText {
                text: "Prova själv — hovra, klicka, tabba"
                role: "overline"
                tone: "muted"
            }

            Row {
                id: interactive

                property int selectedIndex: 1

                spacing: Theme.space.sm

                Repeater {
                    model: ["wifi", "bluetooth", "volume", "bell", "sun", "moon", "power"]

                    delegate: BIconButton {
                        required property int index
                        required property string modelData

                        icon: modelData
                        size: "lg"
                        selected: interactive.selectedIndex === index
                        onClicked: interactive.selectedIndex = index
                    }
                }
            }
        }
    }
}
