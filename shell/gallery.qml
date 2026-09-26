//@ pragma UseQApplication
//@ pragma AppId bifrost.gallery

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Text
import qs.Gallery

// Bifrost component gallery:  scripts/gallery.sh   (Esc or "Stäng" to quit)
// A separate instance with its own layer surface (bifrost:gallery). It shares
// Core/Theme/Config with the shell, so the tuning panel edits the real config.
ShellRoot {
    id: gallery

    Component.onCompleted: Compositor.ensureSurfaceEffects(RunMode.layerPrefix, { blur: Theme.materials.panel.blur > 0, ignoreAlpha: Theme.materials.panel.blurMask || Theme.glass.blurMask })

    PanelWindow {
        id: window

        WlrLayershell.namespace: RunMode.layerNamespace("gallery")
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        implicitWidth: Math.min(screen.width - Theme.space.xxxl * 2, Theme.space.xxxl * 68)
        implicitHeight: screen.height - Theme.space.xxxl * 2

        Item {
            id: root

            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Platform.quit()

            readonly property real gap: Theme.space.xxxl
            readonly property real sideWidth: Theme.space.xxxl * 12

            // Header
            GlassSurface {
                id: header

                material: Theme.materials.bar
                x: root.gap
                y: root.gap
                width: parent.width - root.gap * 2
                height: Theme.control.height.lg + Theme.space.lg * 2

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space.xl
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.lg

                    BIcon {
                        source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
                        size: Theme.icon.size.xl
                        color: Theme.palette.silverBright
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        BText {
                            text: "Bifrost Gallery"
                            role: "heading"
                        }

                        BText {
                            text: Theme.chainIds.join(" → ") + " · " + Theme.variant + " · " + Compositor.displayName + " " + Compositor.version + " · " + RunMode.mode
                            role: "mono"
                            tone: "faint"
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space.lg
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.md

                    BText {
                        text: "Esc stänger"
                        role: "caption"
                        tone: "faint"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BButton {
                        text: "Stäng"
                        icon: "close"
                        onClicked: Platform.quit()
                    }
                }
            }

            // Sections
            Flickable {
                id: flick

                x: 0
                y: header.y + header.height
                width: parent.width - root.sideWidth - root.gap
                height: parent.height - y
                contentHeight: sections.implicitHeight + root.gap * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Dev aid: BIFROST_GALLERY_SCROLL=<px> opens the gallery scrolled.
                Component.onCompleted: contentY = Number(Platform.env("BIFROST_GALLERY_SCROLL")) || 0

                Column {
                    id: sections

                    x: root.gap
                    y: root.gap
                    width: flick.width - root.gap * 2
                    spacing: root.gap

                    StandardGlassSection {
                        width: parent.width
                    }

                    MaterialsSection {
                        width: parent.width
                    }

                    StatesSection {
                        width: parent.width
                    }

                    PrismSection {
                        width: parent.width
                    }

                    ControlsSection {
                        width: parent.width
                    }

                    TypographySection {
                        width: parent.width
                    }

                    IconsSection {
                        width: parent.width
                    }

                    TokensSection {
                        width: parent.width
                    }
                }
            }

            TuningPanel {
                x: parent.width - root.sideWidth - root.gap
                y: header.y + header.height + root.gap
                width: root.sideWidth
                height: parent.height - y - root.gap
            }
        }
    }
}
