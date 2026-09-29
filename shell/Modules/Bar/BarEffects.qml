import QtQuick
import qs.Core
import qs.Components.Effects

// Bifrost Effects on the bar panel (Settings → Appearance → Bifrost Effects):
// glass highlight, bottom edge, prism wash, light-to-dark gradient, centre
// capsule and section dividers. Lies between the panel glass and the widgets,
// in the glass's coordinates. Plain gradients and 1 px lines, no shader and
// no blur; every part is off (not created) when its switch is off.
//
// On the floating or attached panel only: the frame layout has its own rim,
// and without a panel (widget islands) there is no bar surface to decorate.
Item {
    id: fx

    required property var bar            // BarWindow
    required property Item glass         // the panel GlassSurface
    required property Item leftZone
    required property Item centerZone
    required property Item rightZone

    readonly property var cfg: Config.values.effects ? Config.values.effects.bar || ({}) : ({})
    readonly property bool onPanel: bar.panel && !bar.frame
    readonly property bool integrated: bar.widgetStyle === "integrated"
    readonly property real radius: glass.radius
    readonly property real rim: glass.material.borderWidth || 0
    // Straight part of the edges: lines stay clear of the rounded corners.
    readonly property real inset: radius * 0.6

    // Where a menu grows out of the glass (MenuHost's bridge), in these
    // coordinates, and on which edge; the line on that edge leaves it open.
    readonly property var bridge: glass.attachment && glass.attachment.bridge ? glass.attachment.bridge : null
    readonly property bool bridgeTop: bridge !== null && bridge.y + bridge.height / 2 < height / 2

    // Edges are the bar's own: the highlight on its outer side (the screen
    // edge), the dark line on its inner side, toward the windows. A top bar
    // is lit from the top with the line at the bottom; bars laid out as a
    // bottom bar (bottom, and left once turned) have them the other way.
    readonly property bool innerTop: bar.atBottom

    // Surface-wide washes follow the glass's rounded shape.
    Loader {
        anchors.fill: parent
        active: fx.onPanel && fx.cfg.gradient === true
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
        }
    }

    // 1 px glass highlight just inside the outer rim.
    Loader {
        x: fx.inset
        y: fx.innerTop ? fx.height - fx.rim - height : fx.rim
        width: fx.width - fx.inset * 2
        active: fx.onPanel && fx.cfg.highlight === true
        sourceComponent: EffectLine {
            color: Theme.alpha(Theme.effects.highlightColor || "white", fx.cfg.highlightStrength ?? 0)
            gapStart: fx.bridge && fx.bridgeTop !== fx.innerTop ? fx.bridge.x - fx.inset : 0
            gapWidth: fx.bridge && fx.bridgeTop !== fx.innerTop ? fx.bridge.width : 0
        }
    }

    // Very thin dark line along the inner edge.
    Loader {
        x: fx.inset
        y: fx.innerTop ? 0 : fx.height - height
        width: fx.width - fx.inset * 2
        active: fx.onPanel && fx.cfg.bottomEdge === true
        sourceComponent: EffectLine {
            color: Theme.alpha(Theme.effects.edgeColor || "black", fx.cfg.bottomEdgeOpacity ?? 0)
            gapStart: fx.bridge && fx.bridgeTop === fx.innerTop ? fx.bridge.x - fx.inset : 0
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
