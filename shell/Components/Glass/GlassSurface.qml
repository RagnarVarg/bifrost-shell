import QtQuick
import qs.Core

// The single glass material used by every Bifrost surface.
//
//   GlassSurface {
//       material: Theme.materials.panel
//       width: …; height: …
//       BText { … }            // children are placed on the glass body
//   }
//
// Everything visual comes from the material (see themes/_base.json →
// materials): tint + opacity, depth, density, highlight, sheen, grain, inner/outer
// border, radius and elevation. The drop shadow is drawn outside the item's
// bounds, so leave room around it (`shadowExtent`).
//
// `attachment` joins a second rect to the body as one surface (the bar's
// menus grow out of the bar this way). Coordinates are the surface's own; the
// extension may lie outside it (leave room for it too):
//   { ext: Qt.rect(…), extRadii: [br, tr, bl, tl], radii: [br, tr, bl, tl],
//     bridge: Qt.rect(…), fillets: [[x, y, sx, sy], …] }
// `radii` overrides the body corners, `bridge` is a square rect over the seam
// (so no rim is drawn along it) and `fillets` are concave corners where the
// two meet (corner point and signed size toward the open side).
Item {
    id: root

    property var material: Theme.materials.panel
    property real radius: material.radius
    property var attachment: null
    // Additional in-body joins let the frame own dock and dock-panel glass.
    property var attachment2: null
    property var attachment3: null
    property bool paintEnabled: true
    // Frame: a rect cut out of the body (surface coordinates) and its corner
    // radius. The body is then the frame around it.
    property rect hole: Qt.rect(0, 0, 0, 0)
    property real holeRadius: 0
    // The part of the surface a bar menu grows from (MenuHost): all of it by
    // default; a frame's bar strip otherwise.
    property real stripY: 0
    property real stripHeight: height

    default property alias content: body.data
    readonly property alias body: body

    readonly property var elevation: material.elevation || ({})
    // Room outside the body for the shadow and the prism glow.
    readonly property real shadowExtent: Math.max((elevation.opacity || 0) > 0 ? elevation.blur + Math.abs(elevation.y) : 0, (material.glow || 0) > 0 ? Theme.space.xl * 2 : 0)

    // Colours are passed to the shader as explicit non-premultiplied vec4s.
    readonly property color tintColor: material.fill
    readonly property color highlightColor: material.highlightColor
    readonly property color innerBorderColor: material.innerBorder
    readonly property color outerBorderColor: material.outerBorder
    readonly property color shadowColor: Theme.color.shadow

    function vec(c) {
        return Qt.vector4d(c.r, c.g, c.b, c.a);
    }

    function v4(a, fallback) {
        return a && a.length === 4 ? Qt.vector4d(a[0], a[1], a[2], a[3]) : fallback;
    }

    // Bounds of body ∪ extension, in the surface's coordinates.
    readonly property rect extRect: attachment && attachment.ext ? attachment.ext : Qt.rect(0, 0, 0, 0)
    readonly property bool hasExt: extRect.width > 0 && extRect.height > 0
    readonly property real minX: hasExt ? Math.min(0, extRect.x) : 0
    readonly property real minY: hasExt ? Math.min(0, extRect.y) : 0
    readonly property real maxX: hasExt ? Math.max(width, extRect.x + extRect.width) : width
    readonly property real maxY: hasExt ? Math.max(height, extRect.y + extRect.height) : height

    ShaderEffect {
        id: effect
        visible: root.paintEnabled

        readonly property real ox: root.shadowExtent - root.minX
        readonly property real oy: root.shadowExtent - root.minY

        x: root.minX - root.shadowExtent
        y: root.minY - root.shadowExtent
        width: root.maxX - root.minX + root.shadowExtent * 2
        height: root.maxY - root.minY + root.shadowExtent * 2

        function fillet(i) {
            const f = root.attachment && root.attachment.fillets ? root.attachment.fillets[i] : null;
            return f ? Qt.vector4d(f[0] + ox, f[1] + oy, f[2], f[3]) : Qt.vector4d(0, 0, 0, 0);
        }

        property vector2d itemSize: Qt.vector2d(width, height)
        property rect body: Qt.rect(ox, oy, root.width, root.height)
        property vector4d radii: root.v4(root.attachment ? root.attachment.radii : null, Qt.vector4d(root.radius, root.radius, root.radius, root.radius))
        property vector4d ext: root.hasExt ? Qt.vector4d(root.extRect.x + ox, root.extRect.y + oy, root.extRect.width, root.extRect.height) : Qt.vector4d(0, 0, 0, 0)
        property vector4d extRadii: root.v4(root.attachment ? root.attachment.extRadii : null, Qt.vector4d(0, 0, 0, 0))
        property vector4d bridge: {
            const b = root.attachment ? root.attachment.bridge : null;
            return b && root.hasExt ? Qt.vector4d(b.x + ox, b.y + oy, b.width, b.height) : Qt.vector4d(0, 0, 0, 0);
        }
        property vector4d fillet1: fillet(0)
        property vector4d fillet2: fillet(1)
        function extraRect(a, key) {
            const r = a ? a[key] : null;
            return r ? Qt.vector4d(r.x+ox,r.y+oy,r.width,r.height) : Qt.vector4d(0,0,0,0);
        }
        function extraFillet(a, index) {
            const f = a && a.fillets ? a.fillets[index] : null;
            return f ? Qt.vector4d(f[0]+ox,f[1]+oy,f[2],f[3]) : Qt.vector4d(0,0,0,0);
        }
        property vector4d join2: extraRect(root.attachment2, "ext")
        property vector4d join2Radii: root.v4(root.attachment2 ? root.attachment2.extRadii : null, Qt.vector4d(0,0,0,0))
        property vector4d bridge2: extraRect(root.attachment2, "bridge")
        property vector4d join2Fillet1: extraFillet(root.attachment2, 0)
        property vector4d join2Fillet2: extraFillet(root.attachment2, 1)
        property vector4d join3: extraRect(root.attachment3, "ext")
        property vector4d join3Radii: root.v4(root.attachment3 ? root.attachment3.extRadii : null, Qt.vector4d(0,0,0,0))
        property vector4d bridge3: extraRect(root.attachment3, "bridge")
        property vector4d join3Fillet1: extraFillet(root.attachment3, 0)
        property vector4d join3Fillet2: extraFillet(root.attachment3, 1)
        property vector4d tint: root.vec(root.tintColor)
        property vector4d highlightColor: root.vec(root.highlightColor)
        property real highlight: root.material.highlight
        property real sheen: root.material.sheen
        property real depth: root.material.depth
        property real density: root.material.density || 0
        property real grain: root.material.grain
        property vector4d innerBorder: root.vec(root.innerBorderColor)
        property vector4d outerBorder: root.vec(root.outerBorderColor)
        property real borderWidth: root.material.borderWidth
        property real edgeTopBias: root.material.edgeTopBias
        property vector4d shadowColor: root.vec(root.shadowColor)
        property real shadowBlur: root.elevation.blur || 0
        property real shadowY: root.elevation.y || 0
        property real shadowOpacity: root.elevation.opacity || 0
        property real bevel: root.material.bevel || 0
        property real bevelStrength: root.material.bevelStrength || 0
        property real refraction: root.material.refraction || 0
        property real glow: root.material.glow || 0
        // Refraction and glow colours: the material's own (Bifrost Effects'
        // prism on the bar), else the theme's aurora.
        readonly property var stops: root.material.prismStops || Theme.prism.stops || []
        property vector4d glowA: root.vec(stops[0] ? Qt.lighter(stops[0], 1.0) : root.highlightColor)
        property vector4d glowB: root.vec(stops[1] ? Qt.lighter(stops[1], 1.0) : root.highlightColor)
        property vector4d hole: root.hole.width > 0 ? Qt.vector4d(root.hole.x + ox, root.hole.y + oy, root.hole.width, root.hole.height) : Qt.vector4d(0, 0, 0, 0)
        property real holeRadius: root.holeRadius
        property real blurMask: root.material.blurMask || 0
        property vector4d glowC: root.vec(stops[2] ? Qt.lighter(stops[2], 1.0) : root.highlightColor)

        fragmentShader: Qt.resolvedUrl("../Shaders/glass-frame.frag.qsb")
    }

    Item {
        id: body

        anchors.fill: parent
    }
}
