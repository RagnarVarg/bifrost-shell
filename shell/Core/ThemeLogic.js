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

// A surface follows All surfaces only (materials.link), unless it is one of
// materials.unlinked. Same in bifrostctl (surface_linked).
function surfaceLinked(materials, surface) {
    return materials.link === true && surface !== "all" && (materials.unlinked || []).indexOf(surface) < 0;
}

// A surface's setting as it applies: its own value, else All surfaces'. A
// linked surface gets All surfaces' (own values are kept in the config but
// not used). Same in bifrostctl (material_value).
function materialValue(materials, surface) {
    const all = materials.all || {};
    const own = surfaceLinked(materials, surface) ? {} : (materials[surface] || {});
    return p => own[p] !== null && own[p] !== undefined ? own[p] : all[p];
}

// Material settings instance (schema/materials.json) → theme materials it
// styles. "all" applies to every material first; lock and panel only get it.
const surfaceMaterials = {
    bar: ["bar"],
    dock: ["dock"],
    menus: ["popover", "tooltip"],
    launcher: ["launcher"],
    controlCenter: ["controlCenter"],
    notifications: ["notifications"],
    settings: ["settings"],
    settingsGroups: ["settingsGroups"],
    osd: ["osd"]
};
// Materials a theme may omit; they start as a copy of panel.
const panelLike = ["launcher", "controlCenter", "notifications", "settings"];

function argb(c) {
    // "#AARRGGBB" | "#RRGGBB" -> { a, rgb: "#RRGGBB" }
    if (typeof c !== "string")
        return { a: 1, rgb: "#000000" };
    if (c.length === 9)
        return { a: parseInt(c.substring(1, 3), 16) / 255, rgb: "#" + c.substring(3) };
    return { a: 1, rgb: c };
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// Applies one surface's glass settings to a resolved material. `v(prop)` is
// the effective setting (surface override ⊕ all surfaces), null = standard.
// Surfaces drawn in an app window (Settings): the compositor clips their blur
// with the window rounding instead of the alpha mask (schema instance "window").
const windowSurfaces = ["settings"];

// The alpha threshold the compositor's blur mask uses for a surface
// (bifrostctl blur_mask ↔ ignore_alpha), 0 = not blurred. Glass with a shadow
// or glow needs the higher one (see themes/_base.json glass._blurMask).
function blurMaskFor(v, glass, isWindow) {
    const num = p => typeof v(p) === "number" ? v(p) : null;
    const blur = num("blur") !== null ? v("blur") : 20;
    if (!(blur > 0) || isWindow)
        return 0;
    const shadow = num("shadow") !== null ? v("shadow") : 1;
    const glow = num("glow") !== null ? v("glow") : 0;
    // Match the shadow's strength instead of clipping every nonzero shadow to one alpha.
    return shadow > 0 || glow > 0 ? Math.min(0.45, (glass.blurMaskShadowed || 0.12) * Math.max(0.25, shadow, glow > 0 ? 1 : 0)) : (glass.blurMask || 0.01);
}

function applyMaterial(m, v, glass, isWindow) {
    const has = p => v(p) !== null && v(p) !== undefined;
    const k = has("thickness") ? clamp(v("thickness"), 0, 4) : 1;
    // Thickness: darker and denser toward the bottom, a wider bevelled edge
    // with light on the top-left and shade on the bottom-right, a stronger
    // top highlight and a slightly deeper shadow. 0 = a flat film.
    m.thickness = k;
    m.depth = clamp(m.depth * k, 0, 0.92);
    m.density = clamp((m.density || 0) * k, 0, 0.9);
    m.highlight = clamp(m.highlight * (0.4 + 0.6 * k), 0, 0.6);
    m.bevel = (glass.bevel || 3) * k;
    m.bevelStrength = clamp((glass.bevelStrength || 0.06) * k, 0, 0.4);
    m.refraction = has("refraction") ? clamp(v("refraction"), 0, 1) : (glass.refraction || 0);
    m.glow = has("glow") ? clamp(v("glow"), 0, 1) : 0;
    // Background blur: an amount, 0 = off (the compositor's strength is the
    // strongest surface's; see bifrostctl generate_hypr).
    m.blur = m.blur === false ? 0 : typeof v("blur") === "number" ? clamp(v("blur"), 0, 100) : 20;
    m.blurMask = m.blur > 0 ? blurMaskFor(v, glass, isWindow) : 0;
    if (has("transparency"))
        m.opacity = 1 - clamp(v("transparency"), 0, 100) / 100;
    if (has("tint") && /^#[0-9a-fA-F]{6}$/.test(v("tint")))
        m.tint = v("tint");
    if (has("grain"))
        m.grain = clamp(v("grain"), 0, 0.3);
    const inner = argb(m.innerBorder), outer = argb(m.outerBorder);
    const ratio = inner.a > 0 ? outer.a / inner.a : 3;
    if (has("borderOpacity")) {
        inner.a = clamp(v("borderOpacity"), 0, 100) / 100;
        outer.a = clamp(inner.a * ratio, 0, 1);
    }
    if (has("borderColor") && /^#[0-9a-fA-F]{6}$/.test(v("borderColor")))
        inner.rgb = v("borderColor");
    m.innerBorder = withAlpha(inner.rgb, inner.a);
    m.outerBorder = withAlpha(outer.rgb, outer.a);
    if (has("borderWidth"))
        m.borderWidth = clamp(v("borderWidth"), 0, 6);
    if (v("border") === false)
        m.borderWidth = 0;
    if (has("radius"))
        m.radius = clamp(v("radius"), 0, 40);
    // A whole app window: Hyprland clips it (and its blur) to its rounding,
    // which has a maximum; the glass keeps the same corners.
    if (isWindow)
        m.radius = Math.min(m.radius, glass.windowRadiusMax || 20);
    const sh = has("shadow") ? clamp(v("shadow"), 0, 3) : 1;
    const e = m.elevation || {};
    m.elevation = {
        blur: (e.blur || 0) * (0.5 + 0.5 * sh * sh) * (0.85 + 0.15 * k),
        y: (e.y || 0) * (0.6 + 0.4 * sh),
        spread: e.spread || 0,
        opacity: clamp((e.opacity || 0) * Math.pow(sh, 1.5), 0, 1)
    };
    // What Settings shows for "empty" (the standard value).
    m.effective = {
        transparency: Math.round((1 - m.opacity) * 100),
        thickness: k,
        grain: m.grain,
        refraction: m.refraction,
        glow: m.glow,
        borderWidth: m.borderWidth,
        borderOpacity: Math.round(inner.a * 100),
        borderColor: inner.rgb,
        tint: m.tint,
        radius: m.radius,
        shadow: sh,
        blur: m.blur,
        border: m.borderWidth > 0
    };
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
    if (typeof app.accent === "string" && /^#[0-9a-fA-F]{6}$/.test(app.accent)) {
        t.palette.accent = app.accent.toUpperCase();
        t.palette.accentDeep = mixHex(app.accent, "#000000", variant === "light" ? 0.25 : 0.35);
        // Whichever of near-black and near-white contrasts more (WCAG).
        t.palette.accentText = luminance(app.accent) > 0.179 ? "#0B0D10" : "#F5F7FA";
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
    const spaceFactor = (typeof app.spacingScale === "number" ? app.spacingScale : 1) * density.space;
    if (spaceFactor !== 1)
        t.space = scaleNumbers(t.space, spaceFactor);
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
    if (prism.enabled === false || prism.intensity === 0) {
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
    // Glass & materials (schema/materials.json): all surfaces, then each
    // surface's own overrides.
    materials = materials || {};
    const all = materials.all || {};
    const styled = {};
    for (const surface in surfaceMaterials) {
        const v = materialValue(materials, surface);
        for (const k of surfaceMaterials[surface])
            if (t.materials[k]) {
                applyMaterial(t.materials[k], v, t.glass, windowSurfaces.indexOf(surface) >= 0);
                // Internal Settings groups share the window blur, without its radius cap.
                if (k === "settingsGroups") t.materials[k].blurMask = 0;
                styled[k] = true;
            }
    }
    for (const k in t.materials)
        if (!styled[k])
            applyMaterial(t.materials[k], p => all[p], t.glass);
    for (const k in t.materials) {
        const m = t.materials[k];
        m.opacity = clamp(m.opacity, 0, 1);
        m.fill = withAlpha(m.tint, m.opacity);
        m.transparency = Math.round((1 - m.opacity) * 100);
    }
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
