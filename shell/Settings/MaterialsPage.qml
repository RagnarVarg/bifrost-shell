import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Text

// Glass & materials: pick a surface, see its glass live, change any of its
// properties. "All surfaces" is the base; a surface's own value overrides it
// (the chip on a row returns it to inheriting). Rows of an empty setting show
// what it currently resolves to. With "Link all surfaces" every surface
// follows All surfaces (ThemeLogic.surfaceLinked): their rows show the
// linked value and their own values are kept for later. A surface can still
// be changed: that unlinks it (materials.unlinked, SettingsRows), and its
// Linked switch makes it follow All surfaces again.
Flickable {
    id: page

    SettingsScroll { id: wheelScroll; flickable: page }

    readonly property var section: Schema.section("materials")
    readonly property var instances: section && section.template ? section.template.instances : []
    readonly property var props: section && section.template ? section.template.settings.map(p => p.key) : []
    property string surface: "all"
    readonly property var info: instances.find(i => i.id === surface) || ({})
    // The theme material that shows a surface (the preview and the values
    // an empty setting resolves to).
    readonly property var materialOf: ({ all: "panel", bar: "bar", dock: "dock", menus: "popover", launcher: "launcher", controlCenter: "controlCenter", notifications: "notifications", settings: "settings", settingsGroups: "settingsGroups", osd: "osd" })
    readonly property var material: Theme.materials[materialOf[surface]] || Theme.materials.panel
    readonly property var keys: props.map(p => "materials." + surface + "." + p).filter(k => Schema.isSupported(k))
    readonly property int surfaceModified: keys.filter(k => Config.isModified(k)).length
    readonly property bool blurSupported: Compositor.supports("surfaceBlur")
    readonly property bool linked: Config.values.materials.link === true
    readonly property var unlinked: Config.values.materials.unlinked || []
    readonly property bool linkedSurface: linked && surface !== "all" && unlinked.indexOf(surface) < 0
    // The compositor's one blur strength: the strongest surface (bifrostctl).
    readonly property real compositorBlur: Math.max(0, ...instances.map(i => (Theme.materials[materialOf[i.id]] || {}).blur || 0))

    contentHeight: column.implicitHeight + SettingsStyle.contentPadding * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Linked switch of one surface (while Link all surfaces is on). Its own
    // values stay stored either way.
    function setSurfaceLinked(id, on) {
        const rest = unlinked.filter(s => s !== id);
        Config.set("materials.unlinked", on ? rest : rest.concat([id]));
    }

    function modifiedIn(id) {
        return props.filter(p => Config.isModified("materials." + id + "." + p)).length;
    }

    Column {
        id: column

        x: SettingsStyle.contentPadding
        y: SettingsStyle.contentPadding
        width: Math.min(page.width - SettingsStyle.contentPadding * 2, Theme.layout.pageMaxWidth)
        spacing: SettingsStyle.groupSpacing

        Column {
            width: parent.width
            spacing: Theme.space.xs

            BText {
                text: page.section ? page.section.label : ""
                role: "title"
            }

            BText {
                width: parent.width
                text: page.section ? page.section.description : ""
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }
        }

        SettingsRows { keys:["materials.link"] }

        Flow {
            width: parent.width
            spacing: Theme.space.sm

            Repeater {
                model: page.instances

                delegate: BChip {
                    required property var modelData

                    text: modelData.label + (page.linked && modelData.id !== "all" && page.unlinked.indexOf(modelData.id) < 0 ? " · " + I18n.tr("linked") : page.modifiedIn(modelData.id) ? " · " + page.modifiedIn(modelData.id) : "")
                    selected: page.surface === modelData.id
                    onClicked: page.surface = modelData.id
                }
            }
        }

        // Live preview of the selected surface's glass over a busy backdrop.
        Item {
            width: parent.width
            height: SettingsStyle.contentPadding * 6

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.lg
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.prism.stops[0] || Theme.palette.accent
                    }

                    GradientStop {
                        position: 0.5
                        color: Theme.palette.base
                    }

                    GradientStop {
                        position: 1
                        color: Theme.prism.stops[2] || Theme.palette.accentDeep
                    }
                }

                Repeater {
                    model: 7

                    delegate: Rectangle {
                        required property int index

                        x: index * parent.width / 7
                        width: parent.width / 14
                        height: parent.height
                        color: Theme.color.text
                        opacity: 0.08
                    }
                }
            }

            GlassSurface {
                anchors.centerIn: parent
                width: parent.width * 0.62
                height: parent.height * 0.62
                // This preview is inside an app window, not an alpha-masked layer.
                material: Object.assign({}, page.material, {blurMask: 0})

                BText {
                    anchors.centerIn: parent
                    text: page.info.label || ""
                    role: "heading"
                }
            }
        }

        Item {
            width: parent.width
            height: Math.max(surfaceText.implicitHeight, surfaceActions.height)

            Column {
                id: surfaceText

                width: parent.width - surfaceActions.width - Theme.space.lg
                spacing: Theme.space.xxs

                BText {
                    text: page.info.label || ""
                    role: "heading"
                }

                BText {
                    width: parent.width
                    text: page.info.description || ""
                    role: "caption"
                    tone: "muted"
                    wrapMode: Text.WordWrap
                }
            }

            Row {
                id: surfaceActions

                anchors.right: parent.right
                spacing: Theme.space.lg

                Row {
                    visible: page.linked && page.surface !== "all"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.sm

                    BText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Linked")
                        role: "label"
                    }

                    BToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: page.linkedSurface
                        onToggled: c => page.setSurfaceLinked(page.surface, c)
                    }
                }

                BButton {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "ghost"
                    size: "sm"
                    icon: "reset"
                    text: I18n.tr("Reset surface")
                    enabled: page.surfaceModified > 0
                    onClicked: Config.resetKeys(page.keys)
                }
            }
        }

        Banner {
            visible: page.linkedSurface
            tone: "info"
            text: I18n.tr("Linked: this surface uses All surfaces for every property. Changing a property unlinks it; switch Linked back on to make it follow All surfaces again.")
        }

        Banner {
            visible: !page.blurSupported
            tone: "info"
            text: I18n.tr("This compositor can't blur behind Bifrost's surfaces: background blur is unavailable.")
        }

        SettingsRows {
            keys:page.keys
            materialRows:true
            surfaceMaterial:page.material
            linked:page.linkedSurface
            blurSupported:page.blurSupported
            blurStrength:page.compositorBlur
        }

    }

    BScrollIndicator {
        interactive: true
        onDragStarted: wheelScroll.motion.stop()
        flickable: page
    }
}
