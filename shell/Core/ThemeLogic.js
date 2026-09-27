.pragma library

.import "ConfigLogic.js" as L

// Turns "#RRGGBB" + alpha into Qt's "#AARRGGBB".
function withAlpha(hex, alpha) {
    if (typeof hex !== "string" || !/^#[0-9a-fA-F]{6}$/.test(hex))
        return hex;
    const a = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
    return "#" + (a < 16 ? "0" : "") + a.toString(16) + hex.substring(1);
}

function hexRgb(hex) {
    return [1, 3, 5].map(i => parseInt(hex.substring(i, i + 2), 16));
}

function mixHex(a, b, t) {
    const ca = hexRgb(a), cb = hexRgb(b);
    return "#" + ca.map((v, i) => Math.round(v + (cb[i] - v) * t).toString(16).padStart(2, "0")).join("").toUpperCase();
}

// Relative luminance (sRGB), 0..1.
function luminance(hex) {
    const c = hexRgb(hex).map(v => {
        v /= 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

// Replaces every { color, alpha } object with a Qt colour string.
function materialize(node) {
    if (Array.isArray(node))
        return node.map(materialize);
    if (L.isPlainObject(node)) {
        const ks = Object.keys(node);
        if (ks.length === 2 && "color" in node && "alpha" in node && typeof node.alpha === "number")
            return withAlpha(node.color, node.alpha);
        const out = {};
        for (const k of ks)
            out[k] = materialize(node[k]);
        return out;
    }
    return node;
}

// [x1, y1, x2, y2] -> QML Easing.BezierSpline curve.
function bezierCurve(p) {
    return [p[0], p[1], p[2], p[3], 1, 1];
}

function scaleNumbers(obj, factor, skip) {
    const out = {};
    for (const k in obj)
        out[k] = typeof obj[k] === "number" && !(skip && skip.indexOf(k) >= 0) ? Math.round(obj[k] * factor * 100) / 100 : obj[k];
    return out;
}

// Drops documentation keys ("_comment" etc.) at any depth.
function stripMeta(node) {
    if (Array.isArray(node))
        return node.map(stripMeta);
    if (L.isPlainObject(node)) {
        const out = {};
        for (const k in node)
            if (k.charAt(0) !== "_")
                out[k] = stripMeta(node[k]);
        return out;
    }
    return node;
}

// Materials a theme may omit; they start as a copy of panel.
const panelLike = ["launcher", "controlCenter", "notifications", "settings"];

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// Glass groups (schema/materials.json) and the theme materials each styles.
// widgets = the bar's Boxed/Grouped shapes, controlButtons = the control
// center's tiles and sliders (a fill only). Same in bifrostctl (GLASS_GROUPS).
const glassGroups = {
    bar: ["bar"],
    widgets: ["widgets"],
    panels: ["panel", "dock", "popover", "tooltip", "osd", "lock", "launcher", "notifications"],
    controlCenter: ["controlCenter"],
    controlButtons: ["controlButtons"],
    windows: ["settings", "settingsGroups"]
};

function groupOf(material) {
    for (const g in glassGroups)
        if (glassGroups[g].indexOf(material) >= 0)
            return g;
    return "panels";
}

// The glass values a group uses: the shared ones while materials.linked is
// on (the default), else its own where set. A group's blur is on/off; the
// strength is always the shared amount. `custom` = it differs from the
// shared glass (it then has its own shape where it would join another).
// Same in bifrostctl (group_glass).
function groupGlass(s, group) {
    s = s || {};
    const own = s.linked === false ? (s[group] || {}) : {};
    const shared = typeof s.blur === "number" ? s.blur : 20;
    const tint = Object.assign({}, s.tint || {});
    for (const v of ["light", "dark"])
        if (own.tint && typeof own.tint[v] === "string")
            tint[v] = own.tint[v];
    return {
        transparency: typeof own.transparency === "number" ? own.transparency : s.transparency,
        blur: own.blur === false ? 0 : own.blur === true ? (shared > 0 ? shared : 20) : shared,
        tint: tint,
        border: s.border,
        custom: typeof own.transparency === "number" || typeof own.blur === "boolean" || Object.keys(own.tint || {}).some(v => typeof own.tint[v] === "string")
    };
}

// Glass & transparency (schema/materials.json): one set of values for every
// material. `s` is Config.values.materials; unset values keep the theme's
// glass. The tint is set per light/dark variant. Above the theme's own
// transparency the glass's body (density, depth, light, grain, shadow)
// fades with the fill, so 100 % is fully clear: only the border (if on)
// and blur (if on) remain. The Settings window is an app window: Hyprland clips it (and its
// blur) to its rounding instead of the alpha mask, and that rounding has a
// maximum. Same in bifrostctl (blur_mask, material_radius).
function applyMaterial(m, s, glass, name, variant) {
    const isWindow = name === "settings";
    m.blur = m.blur === false ? 0 : typeof s.blur === "number" ? clamp(s.blur, 0, 100) : 20;
    // The compositor blurs a layer only where its alpha is above this.
    // Settings groups share the Settings window's blur.
    m.blurMask = m.blur > 0 && !isWindow && name !== "settingsGroups" ? (glass.blurMaskShadowed || 0.12) : 0;
    const standard = m.opacity;
    if (typeof s.transparency === "number")
        m.opacity = 1 - clamp(s.transparency, 0, 100) / 100;
    const body = standard > 0 ? clamp(m.opacity / standard, 0, 1) : 1;
    if (body < 1) {
        for (const k of ["depth", "density", "highlight", "sheen", "grain"])
            m[k] = (m[k] || 0) * body;
        m.elevation = Object.assign({}, m.elevation, { opacity: ((m.elevation || {}).opacity || 0) * body });
    }
    const tint = (s.tint || {})[variant];
    if (typeof tint === "string" && /^#[0-9a-fA-F]{6}$/.test(tint))
        m.tint = tint;
    if (s.border === false)
        m.borderWidth = 0;
    if (isWindow)
        m.radius = Math.min(m.radius, glass.windowRadiusMax || 20);
    m.thickness = 1;
    m.bevel = glass.bevel || 3;
    m.bevelStrength = (glass.bevelStrength || 0.06) * body;
    m.refraction = (glass.refraction || 0) * body;
    m.glow = 0;
    m.opacity = clamp(m.opacity, 0, 1);
    m.fill = withAlpha(m.tint, m.opacity);
    m.transparency = Math.round((1 - m.opacity) * 100);
}

// Builds final tokens from a theme chain (base first) and appearance settings.
//   chain: [themeData...], variant: "dark"|"light", app: Config.values.appearance
// Returns { tokens, issues }.
function build(chain, variant, app, materials) {
    const issues = [];
    let t = {};
    for (const th of chain) {
        const common = L.clone(th);
        delete common.variants;
        delete common.id;
        delete common.name;
        delete common.extends;
        delete common.version;
        delete common.description;
        t = L.merge(t, stripMeta(common));
    }
    let found = false;
    for (const th of chain) {
        if (th.variants && th.variants[variant]) {
            t = L.merge(t, stripMeta(th.variants[variant]));
            found = true;
        }
    }
    if (!found)
        issues.push("theme has no '" + variant + "' variant");

    app = app || {};
    const prism = app.prism || {};
    const motion = app.motion || {};
    const font = app.font || {};

    // ── Overrides on raw tokens (before references resolve) ──
    // A custom accent replaces the whole accent family, so every derived
    // colour (pressed/deep tone, text on accent, focus, borders) follows it.
    // Accent and foreground are set per light/dark variant.
    const accent = (app.accent || {})[variant];
    if (typeof accent === "string" && /^#[0-9a-fA-F]{6}$/.test(accent)) {
        t.palette.accent = accent.toUpperCase();
        t.palette.accentDeep = mixHex(accent, "#000000", variant === "light" ? 0.25 : 0.35);
        // Whichever of near-black and near-white contrasts more (WCAG).
        t.palette.accentText = luminance(accent) > 0.179 ? "#0B0D10" : "#F5F7FA";
    }
    // Mode-specific foreground affects shell text and monochrome UI icons.
    // App artwork and semantic status colours remain independent.
    const foreground = (app.foreground || {})[variant];
    if (typeof foreground === "string" && /^#[0-9a-fA-F]{6}$/.test(foreground)) {
        t.palette.text = foreground.toUpperCase();
        t.palette.textMuted = foreground.toUpperCase();
        t.palette.textFaint = foreground.toUpperCase();
        t.color.icon = foreground.toUpperCase();
        t.color.iconMuted = foreground.toUpperCase();
    } else if (variant === "light") {
        t.palette.textFaint = mixHex(t.palette.textFaint,t.palette.text,0.35);
        t.color.icon = mixHex(t.palette.silver,t.palette.text,0.2);
    }
    if (typeof app.radiusScale === "number")
        t.radius = scaleNumbers(t.radius, app.radiusScale, ["full"]);
    // Density (compact / standard / spacious) scales spacing, control and
    // row heights and icon sizes everywhere; panel sizes use t.densityFactors
    // through Core/Metrics.
    const density = (t.density && (t.density[app.density] || t.density.standard)) || { space: 1, control: 1, icon: 1, panel: 1 };
    t.densityFactors = { name: t.density && t.density[app.density] ? app.density : "standard", space: density.space, control: density.control, icon: density.icon, panel: density.panel };
    t.densityProfiles = L.clone(t.density);
    delete t.density;
    if (density.space !== 1)
        t.space = scaleNumbers(t.space, density.space);
    if (density.control !== 1) {
        t.control.height = scaleNumbers(t.control.height, density.control);
        for (const k of ["field", "chip"])
            if (t.control[k] && typeof t.control[k].height === "number")
                t.control[k].height = Math.round(t.control[k].height * density.control);
    }
    if (density.icon !== 1)
        t.icon.size = scaleNumbers(t.icon.size, density.icon);
    if (typeof prism.intensity === "number")
        t.prism.intensity = scaleNumbers(t.prism.intensity, prism.intensity);
    // Intensity 0 is "off": prism states fall back to plain fills.
    if (prism.intensity === 0) {
        t.prism.enabled = false;
        for (const k in t.prism.intensity)
            t.prism.intensity[k] = 0;
    }
    if (font.ui)
        t.font.ui = font.ui;
    if (font.mono)
        t.font.mono = font.mono;
    if (typeof font.scale === "number")
        t.font.size = scaleNumbers(t.font.size, font.scale);
    const speed = typeof motion.speed === "number" && motion.speed > 0 ? motion.speed : 1;
    t.motion.duration = scaleNumbers(t.motion.duration, motion.enabled === false ? 0 : 1 / speed);
    t.motion.enabled = motion.enabled !== false;

    for (const k of panelLike)
        if (!t.materials[k])
            t.materials[k] = L.clone(t.materials.panel);

    // ── Resolve references, then colours ──
    t = materialize(L.resolveRefs(t, t));

    // ── Derived values ──
    // The widget boxes start as the bar's glass, the control center's
    // buttons as the panel glass.
    t.materials.widgets = L.clone(t.materials.bar);
    t.materials.controlButtons = L.clone(t.materials.panel);
    for (const k in t.materials) {
        const g = groupGlass(materials, groupOf(k));
        applyMaterial(t.materials[k], g, t.glass, k, variant);
        t.materials[k].custom = g.custom;
    }
    // Buttons without their own glass keep the plain control fill.
    if (!t.materials.controlButtons.custom)
        t.materials.controlButtons.fill = t.color.controlFill;
    if (t.prism.enabled === false)
        for (const k in t.states)
            if (t.states[k].fill === "prism")
                t.states[k].fill = "solid";
    t.motion.curve = {};
    for (const k in t.motion.easing)
        t.motion.curve[k] = bezierCurve(t.motion.easing[k]);

    const unresolved = [];
    (function scan(n, p) {
        if (typeof n === "string" && n.charAt(0) === "@")
            unresolved.push(p + " → " + n);
        else if (n && typeof n === "object")
            for (const k in n)
                scan(n[k], p ? p + "." + k : k);
    })(t, "");
    for (const u of unresolved)
        issues.push("unresolved token reference " + u);

    return { tokens: t, issues: issues };
}
