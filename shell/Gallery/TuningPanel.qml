import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Text

// Live tuning of the appearance settings. Writes through Config, so the
// values land in ~/.config/bifrost/config.json exactly as Settings will.
GlassSurface {
    id: panel

    material: Theme.materials.panel

    component SliderRow: Column {
        id: row

        property string key: ""
        property real from: 0
        property real to: 1
        property real step: 0.01
        property int decimals: 2
        readonly property var def: Schema.def(key)
        readonly property var raw: Config.get(key)
        property real fallback: 0
        property real shownValue: raw === null || raw === undefined ? fallback : raw

        width: parent.width
        spacing: Theme.space.xs

        Item {
            width: parent.width
            height: title.implicitHeight

            BText {
                id: title

                text: row.def ? row.def.label : row.key
                role: "label"
            }

            BText {
                anchors.right: parent.right
                role: "mono"
                tone: Config.isModified(row.key) ? "accent" : "muted"
                text: (row.raw === null ? "tema " : "") + Number(row.shownValue).toFixed(row.decimals)
            }
        }

        BSlider {
            width: parent.width
            from: row.from
            to: row.to
            stepSize: row.step
            value: row.shownValue
            onMoved: v => Config.set(row.key, v)
        }
    }

    component ToggleRow: Item {
        id: trow

        property string key: ""
        readonly property var def: Schema.def(key)

        width: parent.width
        height: Theme.control.height.md

        BText {
            anchors.verticalCenter: parent.verticalCenter
            text: trow.def ? trow.def.label : trow.key
            role: "label"
        }

        BToggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Config.get(trow.key) === true
            onToggled: c => Config.set(trow.key, c)
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.space.xl
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: parent.width
            spacing: Theme.space.lg

            BText {
                text: "Justera"
                role: "title"
            }

            BText {
                width: parent.width
                text: "Ändringarna sparas i ~/.config/bifrost/config.json och syns direkt i allt."
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            BSegmented {
                width: parent.width
                model: ["Mörkt", "Ljust"]
                currentIndex: Config.get("appearance.mode") === "light" ? 1 : 0
                onActivated: i => Config.set("appearance.mode", i === 1 ? "light" : "dark")
            }

            BText {
                text: "Glas"
                role: "overline"
                tone: "muted"
            }

            SliderRow {
                key: "materials.all.thickness"
                to: 4
                step: 0.05
                fallback: 1
            }

            SliderRow {
                key: "materials.all.grain"
                to: 0.12
                step: 0.005
                decimals: 3
                fallback: Theme.glass.grain
            }

            SliderRow {
                key: "materials.all.refraction"
                to: 1
                step: 0.05
                fallback: 0
            }

            SliderRow {
                key: "materials.all.glow"
                to: 1
                step: 0.05
            }

            SliderRow {
                key: "materials.all.shadow"
                to: 3
                step: 0.05
            }

            BText {
                text: "Form"
                role: "overline"
                tone: "muted"
            }

            SliderRow {
                key: "appearance.radiusScale"
                to: 2
                step: 0.05
            }

            SliderRow {
                key: "appearance.spacingScale"
                from: 0.5
                to: 2
                step: 0.05
            }

            BText {
                text: "Bifrost-prisma"
                role: "overline"
                tone: "muted"
            }

            ToggleRow {
                key: "appearance.prism.enabled"
            }

            SliderRow {
                key: "appearance.prism.intensity"
                to: 2
                step: 0.05
            }

            BText {
                text: "Rörelse & text"
                role: "overline"
                tone: "muted"
            }

            ToggleRow {
                key: "appearance.motion.enabled"
            }

            SliderRow {
                key: "appearance.motion.speed"
                from: 0.25
                to: 3
                step: 0.05
            }

            SliderRow {
                key: "appearance.font.scale"
                from: 0.75
                to: 1.5
                step: 0.05
            }

            Row {
                spacing: Theme.space.md

                BButton {
                    text: "Återställ utseende"
                    icon: "close"
                    onClicked: {
                        for (const s of ["appearance", "glass", "typography", "motion"])
                            Config.resetSection(s);
                    }
                }
            }
        }
    }
}
