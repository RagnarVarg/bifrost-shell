.pragma library

// Helpers shared by the Bifrost Effects (Settings → Appearance → Bifrost
// Effects).

// `c` with its HSL saturation scaled by `amount` (0 = grey, 1 = unchanged)
// and alpha `a`.
function tone(c, amount, a) {
    c = Qt.color(c);
    const s = Math.max(0, c.hslSaturation) * Math.max(0, Math.min(1, amount));
    return Qt.hsla(Math.max(0, c.hslHue), s, c.hslLightness, a);
}

// The bar's glass material with the top-bar effects applied. The glass
// shader (GlassSurface) already draws the rim, light and refraction along
// the real shape — rounded corners, the frame's window hole, menus joined to
// the bar — so the effects strengthen those instead of drawing on top:
//   highlight  → the light 1 px inner rim (brighter at the top)
//   bottomEdge → the dark 1 px hairline outside the rim (toward the windows)
//   prism      → refraction: a faint colour split just inside the rim, in the
//                effects' cyan → blue → violet, toned by prismSaturation
//   gradient   → the top light band and the depth (darker toward the bottom)
// `cfg` is Config.values.effects.bar, `tokens` Theme.effects.
function barMaterial(m, cfg, tokens) {
    if (!cfg || !m)
        return m;
    const out = Object.assign({}, m);
    const strength = v => Math.max(0, Math.min(1, Number(v) || 0));
    if (cfg.highlight === true && out.innerBorder !== undefined) {
        const base = Qt.color(out.innerBorder);
        out.innerBorder = Qt.alpha(Qt.color(tokens.highlightColor || base), Math.min(1, base.a + strength(cfg.highlightStrength)));
    }
    if (cfg.bottomEdge === true && out.outerBorder !== undefined) {
        const base = Qt.color(out.outerBorder);
        out.outerBorder = Qt.alpha(Qt.color(tokens.edgeColor || base), Math.min(1, base.a + strength(cfg.bottomEdgeOpacity)));
    }
    const stops = tokens.prism || [];
    if (cfg.prism === true && stops.length >= 3) {
        out.refraction = (out.refraction || 0) + strength(cfg.prismStrength) * (tokens.prismRefraction || 1);
        out.prismStops = stops.map(c => tone(c, strength(cfg.prismSaturation), 1));
    }
    if (cfg.gradient === true) {
        const s = strength(cfg.gradientStrength);
        out.highlight = Math.min(1, (out.highlight || 0) + s);
        out.depth = Math.min(1, (out.depth || 0) + s);
    }
    return out;
}
