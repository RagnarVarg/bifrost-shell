import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Text

// Base controls in their variants. Interactive, but nothing is persisted.
GallerySection {
    title: "Kontroller"
    subtitle: "Grundkontroller byggda enbart av tokens, GlassSurface och StateLayer."

    component Label: BText {
        role: "overline"
        tone: "muted"
    }

    Column {
        width: parent.width
        spacing: Theme.space.xxl

        Column {
            spacing: Theme.space.sm

            Label {
                text: "Knappar"
            }

            Row {
                spacing: Theme.space.md

                BButton {
                    text: "Primär"
                    variant: "primary"
                }

                BButton {
                    text: "Sekundär"
                }

                BButton {
                    text: "Ghost"
                    variant: "ghost"
                }

                BButton {
                    text: "Med ikon"
                    icon: "tune"
                }

                BButton {
                    text: "Vald"
                    selected: true
                }

                BButton {
                    text: "Inaktiv"
                    enabled: false
                }

                BButton {
                    text: "Liten"
                    size: "sm"
                    anchors.verticalCenter: parent.verticalCenter
                }

                BButton {
                    text: "Stor"
                    size: "lg"
                    variant: "primary"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Row {
            spacing: Theme.space.xxxl

            Column {
                spacing: Theme.space.sm

                Label {
                    text: "Toggles"
                }

                Row {
                    spacing: Theme.space.lg

                    BToggle {
                        id: t1

                        checked: true
                        onToggled: c => checked = c
                    }

                    BToggle {
                        id: t2

                        onToggled: c => checked = c
                    }

                    BToggle {
                        checked: true
                        enabled: false
                    }
                }
            }

            Column {
                spacing: Theme.space.sm

                Label {
                    text: "Slider"
                }

                Row {
                    spacing: Theme.space.lg

                    BSlider {
                        id: slider

                        width: Theme.space.xxxl * 8
                        value: 0.62
                        onMoved: v => value = v
                    }

                    BText {
                        text: Math.round(slider.value * 100) + " %"
                        role: "mono"
                        tone: "muted"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                spacing: Theme.space.sm

                Label {
                    text: "Segmenterad"
                }

                BSegmented {
                    id: seg

                    model: ["Dag", "Vecka", "Månad"]
                    currentIndex: 1
                    onActivated: i => currentIndex = i
                }
            }

            Column {
                spacing: Theme.space.sm

                Label {
                    text: "Färgväljare · " + galleryPicker.current
                }

                BColorPicker {
                    id: galleryPicker

                    property string current: Theme.palette.accent

                    width: Theme.layout.editorWidth
                    color: current
                    onPicked: hex => current = hex
                }
            }
        }

        Row {
            spacing: Theme.space.xxxl

            Column {
                spacing: Theme.space.sm

                Label {
                    text: "Textfält"
                }

                BTextField {
                    width: Theme.space.xxxl * 10
                    icon: "search"
                    placeholder: "Sök appar, filer och inställningar"
                }
            }

            Column {
                spacing: Theme.space.sm

                Label {
                    text: "Chips"
                }

                Row {
                    id: chips

                    property int current: 0

                    spacing: Theme.space.sm

                    Repeater {
                        model: ["Alla", "Appar", "Filer", "Inställningar"]

                        delegate: BChip {
                            required property int index
                            required property string modelData

                            text: modelData
                            selected: chips.current === index
                            onClicked: chips.current = index
                        }
                    }
                }
            }
        }

        Column {
            spacing: Theme.space.sm

            Label {
                text: "Rader i en popover"
            }

            GlassSurface {
                material: Theme.materials.popover
                width: Theme.space.xxxl * 14
                height: rows.implicitHeight + Theme.space.sm * 2

                Column {
                    id: rows

                    property int current: 0

                    anchors.fill: parent
                    anchors.margins: Theme.space.sm

                    BListRow {
                        width: parent.width
                        icon: "display"
                        title: "Skärm"
                        subtitle: "DP-2 · 5120 × 1440 · 240 Hz"
                        selected: rows.current === 0
                        onClicked: rows.current = 0

                        BIconButton {
                            icon: "chevron-right"
                            size: "sm"
                        }
                    }

                    BListRow {
                        width: parent.width
                        icon: "bell"
                        title: "Stör ej"
                        subtitle: "Tysta notiser tills i morgon"
                        selected: rows.current === 1
                        onClicked: rows.current = 1

                        BToggle {
                            id: dnd

                            onToggled: c => checked = c
                        }
                    }

                    BDivider {
                        width: parent.width
                    }

                    BListRow {
                        width: parent.width
                        icon: "palette"
                        title: "Utseende"
                        subtitle: "Bifrost Graphite · mörkt"
                        selected: rows.current === 2
                        onClicked: rows.current = 2
                    }
                }
            }
        }
    }
}
