import QtQuick
import qs.Core
import qs.Components.Effects

// Bifrost Effects drawn on the bar (Settings → Appearance → Bifrost
// Effects): the centre capsule and the section dividers. The glass effects
// (highlight, edge, prism, gradient) are part of the bar's material instead
// (Effects.barMaterial in BarWindow), so the glass shader draws them along the
// real shape.
//
// Only with integrated widgets on a panel (or the frame's bar strip): boxed
// and grouped widgets already sit in their own glass.
Item {
    id: fx

    required property var bar            // BarWindow
    required property Item leftZone
    required property Item centerZone
    required property Item rightZone

    readonly property var cfg: Config.values.effects ? Config.values.effects.bar || ({}) : ({})
    readonly property bool shown: bar.panel && bar.widgetStyle === "integrated" && centerZone.width > 0 && (centerZone.entries || []).length > 0
    readonly property real capsulePad: Theme.effects.capsulePadding ?? 0
    readonly property real capsuleX: centerZone.x - capsulePad
    readonly property real capsuleRight: centerZone.x + centerZone.width + capsulePad

    // The centre (clock) raised a little: a discreet glass capsule.
    Loader {
        x: fx.capsuleX
        y: fx.centerZone.y
        width: fx.capsuleRight - fx.capsuleX
        height: fx.centerZone.height
        active: fx.shown && fx.cfg.capsule === true
        sourceComponent: GlassCapsule {}
    }

    Loader {
        anchors.fill: parent
        active: fx.shown && fx.cfg.dividers === true
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
