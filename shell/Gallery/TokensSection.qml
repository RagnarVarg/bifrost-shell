import QtQuick
import qs.Core
import qs.Components.Glass
import qs.Components.Text

// The raw tokens: palette, aurora, radius, spacing and elevation.
GallerySection {
    title: "Tokens"
    subtitle: "Allt ovan kommer härifrån (themes/_base.json + bifrost-graphite.json)."

    component Swatch: Column {
        id: swatch

        property string name: ""
        property color value: "transparent"

        spacing: Theme.space.xs

        Rectangle {
            width: Theme.space.xxxl * 2
            height: Theme.space.xxxl * 1.25
            radius: Theme.radius.sm
            color: swatch.value
            border.width: Theme.border.hairline
            border.color: Theme.color.hairline
        }

        BText {
            text: swatch.name
            role: "mono"
            tone: "faint"
        }
    }

    Column {
        width: parent.width
        spacing: Theme.space.xxl

        Flow {
            width: parent.width
            spacing: Theme.space.lg

            Repeater {
                model: ["void", "base", "surface", "surfaceRaised", "surfaceHover", "text", "textMuted", "textFaint", "silver", "silverBright", "accent", "accentDeep", "success", "warning", "danger"]

                delegate: Swatch {
                    required property string modelData

                    name: modelData
                    value: Theme.palette[modelData]
                }
            }

            Repeater {
                model: Theme.prism.stops

                delegate: Swatch {
                    required property int index
                    required property string modelData

                    name: "aurora " + index
                    value: modelData
                }
            }
        }

        Row {
            spacing: Theme.space.xxxl

            Column {
                spacing: Theme.space.sm

                BText {
                    text: "Radius"
                    role: "overline"
                    tone: "muted"
                }

                Row {
                    spacing: Theme.space.lg

                    Repeater {
                        model: ["xs", "sm", "md", "lg", "xl"]

                        delegate: Column {
                            id: rcell

                            required property string modelData

                            spacing: Theme.space.xs

                            Rectangle {
                                width: Theme.space.xxxl * 1.5
                                height: width
                                radius: Theme.radius[rcell.modelData]
                                color: Theme.color.controlFill
                                border.width: Theme.border.hairline
                                border.color: Theme.color.innerBorder
                            }

                            BText {
                                text: rcell.modelData + " " + Theme.radius[rcell.modelData]
                                role: "mono"
                                tone: "faint"
                            }
                        }
                    }
                }
            }

            Column {
                spacing: Theme.space.sm

                BText {
                    text: "Spacing"
                    role: "overline"
                    tone: "muted"
                }

                Repeater {
                    model: ["xxs", "xs", "sm", "md", "lg", "xl", "xxl", "xxxl"]

                    delegate: Row {
                        id: srow

                        required property string modelData

                        spacing: Theme.space.md

                        BText {
                            width: Theme.space.xxxl * 2
                            text: srow.modelData + " " + Theme.space[srow.modelData]
                            role: "mono"
                            tone: "faint"
                        }

                        Rectangle {
                            width: Theme.space[srow.modelData]
                            height: Theme.space.sm
                            radius: Theme.radius.xs
                            color: Theme.color.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Column {
                spacing: Theme.space.sm

                BText {
                    text: "Elevation"
                    role: "overline"
                    tone: "muted"
                }

                Row {
                    spacing: Theme.space.xxxl

                    Repeater {
                        model: ["none", "low", "mid", "high"]

                        delegate: GlassSurface {
                            required property string modelData

                            width: Theme.space.xxxl * 2.5
                            height: Theme.space.xxxl * 2
                            material: Object.assign({}, Theme.materials.popover, { elevation: Theme.elevation[modelData] })

                            BText {
                                anchors.centerIn: parent
                                text: parent.modelData
                                role: "mono"
                                tone: "muted"
                            }
                        }
                    }
                }
            }
        }
    }
}
