import QtQuick
import qs.Core
import qs.Components.Effects

// Bifrost Effects on the bar panel (Settings → Appearance → Bifrost Effects):
// glass highlight, bottom edge, prism wash, light-to-dark gradient, centre
// capsule and section dividers. Lies between the panel glass and the widgets,
// in the glass's coordinates. Plain gradients and 1 px lines, no shader and
// no blur; every part is off (not created) when its switch is off.
//
// On the floating or attached panel, and on the bar strip of the frame
// layout. In the frame the strip runs on into the frame's sides: the prism
// fades out toward them, the inner line stops where the window hole
// rounds, and the light-to-dark gradient is left out (it would end in a
// visible seam at the corners). Without a panel (widget islands) there is
// no bar surface to decorate.
Item {
    id: fx

    required property var bar            // BarWindow
    required property Item glass         // the panel GlassSurface
    required property Item frameSurface  // the frame layout's GlassSurface
    required property Item leftZone
    required property Item centerZone
    required property Item rightZone

    readonly property var cfg: Config.values.effects ? Config.values.effects.bar || ({}) : ({})
    readonly property bool frame: bar.frame
    readonly property bool onPanel: bar.panel
    readonly property bool integrated: bar.widgetStyle === "integrated"
    readonly property Item surface: frame ? frameSurface : glass
    readonly property real radius: frame ? 0 : glass.radius
    readonly property real rim: surface.material.borderWidth || 0
    // Straight part of the edges: lines stay clear of the rounded corners
    // (the panel's own, or in the frame the window hole's, on the inner side).
    readonly property real outerInset: frame ? 0 : radius * 0.6
    readonly property real innerInset: frame ? frameSurface.holeRadius : radius * 0.6

    // Where a menu grows out of the glass (MenuHost's bridge), in these
    // coordinates, and on which edge; the line on that edge leaves it open.
    readonly property var bridge: {
        const b = surface.attachment && surface.attachment.bridge ? surface.attachment.bridge : null;
        return b ? Qt.rect(b.x + surface.x, b.y + surface.y, b.width, b.height) : null;
    }
    readonly property bool bridgeTop: bridge !== null && bridge.y + bridge.height / 2 < height / 2

    // Edges are the bar's own: the highlight on its outer side (the screen
    // edge), the dark line on its inner side, toward the windows. A top bar
    // is lit from the top with the line at the bottom; bars laid out as a
    // bottom bar (bottom, and left once turned) have them the other way.
    readonly property bool innerTop: bar.atBottom

    // Surface-wide washes follow the glass's rounded shape.
    Loader {
        anchors.fill: parent
        active: fx.onPanel && !fx.frame && fx.cfg.gradient === true
        sourceComponent: ShadeGradient {
            radius: fx.radius
            rotation: fx.innerTop ? 180 : 0
            strength: fx.cfg.gradientStrength ?? 0
        }
    }

    Loader {
        anchors.fill: parent
        active: fx.onPanel && fx.cfg.prism === true
        sourceComponent: PrismWash {
            radius: fx.radius
            strength: fx.cfg.prismStrength ?? 0
            saturation: fx.cfg.prismSaturation ?? 0
            fadeEnds: fx.frame
        }
    }

    // 1 px glass highlight just inside the outer rim.
    Loader {
        x: fx.outerInset
        y: fx.innerTop ? fx.height - fx.rim - height : fx.rim
        width: fx.width - fx.outerInset * 2
        active: fx.onPanel && fx.cfg.highlight === true
        sourceComponent: EffectLine {
            color: Theme.alpha(Theme.effects.highlightColor || "white", fx.cfg.highlightStrength ?? 0)
            gapStart: fx.bridge && fx.bridgeTop !== fx.innerTop ? fx.bridge.x - fx.outerInset : 0
            gapWidth: fx.bridge && fx.bridgeTop !== fx.innerTop ? fx.bridge.width : 0
        }
    }

    // Very thin dark line along the inner edge.
    Loader {
        x: fx.innerInset
        y: fx.innerTop ? 0 : fx.height - height
        width: fx.width - fx.innerInset * 2
        active: fx.onPanel && fx.cfg.bottomEdge === true
        sourceComponent: EffectLine {
            color: Theme.alpha(Theme.effects.edgeColor || "black", fx.cfg.bottomEdgeOpacity ?? 0)
            gapStart: fx.bridge && fx.bridgeTop === fx.innerTop ? fx.bridge.x - fx.innerInset : 0
            gapWidth: fx.bridge && fx.bridgeTop === fx.innerTop ? fx.bridge.width : 0
        }
    }

    // Centre capsule and dividers belong to integrated widgets: boxed and
    // grouped widgets already sit in their own glass.
    readonly property bool hasCenter: centerZone.width > 0 && (centerZone.entries || []).length > 0
    readonly property real capsulePad: Theme.effects.capsulePadding ?? 0
    readonly property real capsuleX: centerZone.x - capsulePad
    readonly property real capsuleRight: centerZone.x + centerZone.width + capsulePad

    Loader {
        x: fx.capsuleX
        y: fx.centerZone.y
        width: fx.capsuleRight - fx.capsuleX
        height: fx.centerZone.height
        active: fx.bar.panel && fx.integrated && fx.hasCenter && fx.cfg.capsule === true
        sourceComponent: GlassCapsule {}
    }

    Loader {
        anchors.fill: parent
        active: fx.bar.panel && fx.integrated && fx.hasCenter && fx.cfg.dividers === true
        sourceComponent: Item {
            // Halfway between each side's widgets and the centre (its
            // capsule when shown), only where that side has widgets.
            readonly property real leftEnd: fx.leftZone.x + fx.leftZone.width
            readonly property real centreStart: fx.cfg.capsule === true ? fx.capsuleX : fx.centerZone.x
            readonly property real centreEnd: fx.cfg.capsule === true ? fx.capsuleRight : fx.centerZone.x + fx.centerZone.width

            SectionDivider {
                visible: fx.leftZone.width > 0 && parent.centreStart - parent.leftEnd > width * 4
                x: Math.round((parent.leftEnd + parent.centreStart) / 2)
            }

            SectionDivider {
                visible: fx.rightZone.width > 0 && fx.rightZone.x - parent.centreEnd > width * 4
                x: Math.round((parent.centreEnd + fx.rightZone.x) / 2)
            }
        }
    }
}
