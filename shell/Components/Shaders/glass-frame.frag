#version 440
// Bifrost glass material. Draws, in one pass: drop shadow, tinted body with
// depth and density (darker and denser toward the bottom), top highlight, diagonal sheen, grain, a
// light inner rim that is brighter at the top, and a dark outer hairline.
// All parameters come from Theme.materials via GlassSurface.qml.
//
// The shape is the body (per-corner radii) optionally joined with an
// extension rect (a bar menu growing out of the bar) and up to two concave
// fillets where they meet, so body and extension read as one surface with one
// rim and one shadow.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 body;            // x, y, w, h of the glass body inside the item (px)
    vec4 radii;           // body corners: bottom-right, top-right, bottom-left, top-left
    vec4 ext;             // extension rect x, y, w, h (w = 0: none)
    vec4 extRadii;        // extension corners, same order as radii
    vec4 bridge;          // square rect over the seam, so it is deep inside the shape
    vec4 fillet1;         // concave fillet: corner x, y and signed size sx, sy (0: none)
    vec4 fillet2;
    vec4 join2;
    vec4 join2Radii;
    vec4 bridge2;
    vec4 join2Fillet1;
    vec4 join2Fillet2;
    vec4 join3;
    vec4 join3Radii;
    vec4 bridge3;
    vec4 join3Fillet1;
    vec4 join3Fillet2;
    vec4 tint;            // material fill (rgba, alpha = opacity)
    vec4 highlightColor;
    float highlight;
    float sheen;
    float depth;
    float density;
    float grain;
    vec4 innerBorder;
    vec4 outerBorder;
    float borderWidth;
    float edgeTopBias;
    vec4 shadowColor;
    float shadowBlur;
    float shadowY;
    float shadowOpacity;
    float bevel;          // width of the bevelled inner edge (px)
    float bevelStrength;  // light/shade on the bevel
    float refraction;     // light bending along the bevel (caustic + colour split)
    float glow;           // prism glow outside the rim
    vec4 glowA;           // aurora stops for refraction and glow
    vec4 glowB;
    vec4 glowC;
    vec4 hole;            // frame: rect cut out of the body (w = 0: none)
    float holeRadius;
    float blurMask;       // compositor blur threshold (ignore_alpha) when blurred, else 0
};

// Rounded box with per-corner radii (y grows downward):
// r = (bottom-right, top-right, bottom-left, top-left).
float sdRoundBox4(vec2 p, vec2 b, vec4 r) {
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    vec2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

float sdBox(vec2 p, vec2 b) {
    vec2 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// Concave fillet in the corner at f.xy that opens toward f.zw: a square of
// that size minus a circle centred at its far corner. The square also reaches
// back across the corner, where both shapes are solid anyway, so the seam
// stays inside the shape.
float sdFillet(vec2 p, vec4 f) {
    float s = abs(f.z);
    if (s < 0.5 || abs(f.w) < 0.5)
        return 1e5;
    float box = sdBox(p - f.xy, abs(f.zw));
    return max(box, s - length(p - (f.xy + f.zw)));
}

vec4 clampRadii(vec4 r, vec2 half_) {
    return min(r, vec4(min(half_.x, half_.y)));
}

float shape(vec2 p) {
    vec2 half_ = body.zw * 0.5;
    float d = sdRoundBox4(p - body.xy - half_, half_, clampRadii(radii, half_));
    // Frame: the body minus a rounded hole (the screen area inside the frame).
    if (hole.z > 0.5 && hole.w > 0.5) {
        vec2 hh = hole.zw * 0.5;
        d = max(d, -sdRoundBox4(p - hole.xy - hh, hh, vec4(min(holeRadius, min(hh.x, hh.y)))));
    }
    if (ext.z > 0.5 && ext.w > 0.5) {
        vec2 eh = ext.zw * 0.5;
        d = min(d, sdRoundBox4(p - ext.xy - eh, eh, clampRadii(extRadii, eh)));
        if (bridge.z > 0.5 && bridge.w > 0.5)
            d = min(d, sdBox(p - bridge.xy - bridge.zw * 0.5, bridge.zw * 0.5));
        d = min(d, sdFillet(p, fillet1));
        d = min(d, sdFillet(p, fillet2));
    }
    if (join2.z > 0.5 && join2.w > 0.5) {
        vec2 h = join2.zw * 0.5;
        d = min(d, sdRoundBox4(p-join2.xy-h, h, clampRadii(join2Radii,h)));
        d = min(d, sdBox(p-bridge2.xy-bridge2.zw*0.5,bridge2.zw*0.5));
        d = min(d, sdFillet(p,join2Fillet1));
        d = min(d, sdFillet(p,join2Fillet2));
    }
    if (join3.z > 0.5 && join3.w > 0.5) {
        vec2 h = join3.zw * 0.5;
        d = min(d, sdRoundBox4(p-join3.xy-h, h, clampRadii(join3Radii,h)));
        d = min(d, sdBox(p-bridge3.xy-bridge3.zw*0.5,bridge3.zw*0.5));
        d = min(d, sdFillet(p,join3Fillet1));
        d = min(d, sdFillet(p,join3Fillet2));
    }
    return d;
}

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

vec4 over(vec4 src, vec4 dst) {
    return src + dst * (1.0 - src.a);
}

// Aurora colour at position t (0..1) around the rim.
vec3 aurora(float t) {
    t = fract(t) * 3.0;
    if (t < 1.0)
        return mix(glowA.rgb, glowB.rgb, t);
    if (t < 2.0)
        return mix(glowB.rgb, glowC.rgb, t - 1.0);
    return mix(glowC.rgb, glowA.rgb, t - 2.0);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;

    float d = shape(px);
    float aa = max(fwidth(d), 0.75);
    float inside = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, d);
    // Depth runs over the body; an extension below continues the body's
    // bottom, one above continues its top.
    float t = clamp((px.y - body.y) / max(body.w, 1.0), 0.0, 1.0);      // 0 top → 1 bottom
    // A frame is thin everywhere: shade it evenly instead of top → bottom.
    if (hole.z > 0.5 && hole.w > 0.5)
        t = 0.35;
    // The highlight belongs to the shape's top edge: over an extension that
    // rises above the body, that edge is the extension's.
    bool extAbove = ext.z > 0.5 && ext.w > 0.5 && ext.y < body.y - 0.5;
    float fw = max(abs(fillet1.z), abs(fillet2.z));
    float top = extAbove && px.x > ext.x - fw && px.x < ext.x + ext.z + fw ? ext.y : body.y;
    float th = clamp((px.y - top) / max(body.w, 1.0), 0.0, 1.0);
    vec2 uv = clamp((px - body.xy) / max(body.zw, vec2(1.0)), 0.0, 1.0);

    vec4 outc = vec4(0.0);

    // Shadow, only outside the body so it never darkens the glass itself.
    if (shadowOpacity > 0.0 && shadowBlur > 0.0) {
        float ds = shape(px - vec2(0.0, shadowY));
        float s = 1.0 - smoothstep(-shadowBlur * 0.25, shadowBlur, ds);
        s = s * s * shadowOpacity * smoothstep(-aa, aa, d);
        outc = vec4(shadowColor.rgb * s, s);
    }

    // Dark outer hairline just outside the edge.
    if (borderWidth > 0.0) {
        float o = smoothstep(-aa * 0.5, aa * 0.5, d) * (1.0 - smoothstep(borderWidth - aa * 0.5, borderWidth + aa * 0.5, d));
        float oa = outerBorder.a * o;
        outc = over(vec4(outerBorder.rgb * oa, oa), outc);
    }

    // Body: clearest at the top edge, darker (depth) and denser (density)
    // toward the bottom — reads as thick glass without frosting it.
    vec3 col = tint.rgb * (1.0 - depth * t);
    float a = tint.a + density * t * (1.0 - tint.a);
    vec4 bodyc = vec4(col * a, a);

    // Top highlight band and a soft diagonal sheen (premultiplied, additive-ish).
    float h = highlight * (1.0 - smoothstep(0.0, 0.42, th));
    float band = (uv.x * 0.55 + uv.y) - 0.38;
    float sh = sheen * exp(-band * band / 0.018);
    float la = clamp(h + sh, 0.0, 1.0);
    bodyc = over(vec4(highlightColor.rgb * la, la), bodyc);

    // Grain: luminance noise, fixed to the pixel grid so it doesn't shimmer.
    float n = hash(floor(px)) - 0.5;
    bodyc.rgb = max(bodyc.rgb + n * grain * bodyc.a, 0.0);

    // Outward normal of the shape (from the distance field) for the bevel,
    // refraction and glow; the angle around the rim picks aurora colours.
    vec2 grad = vec2(dFdx(d), dFdy(d));
    vec2 nrm = length(grad) > 1e-5 ? normalize(grad) : vec2(0.0, -1.0);
    float around = atan(nrm.y, nrm.x) / 6.2831853 + 0.5;

    // Bevelled edge (thickness): within `bevel` px of the rim the glass
    // tilts outward, so edges facing the light (top-left) catch it and the
    // opposite ones fall into shade.
    if (bevel > 0.5 && bevelStrength > 0.0) {
        float band = 1.0 - smoothstep(0.0, bevel, -d);
        band *= band * inside;
        float lit = dot(nrm, normalize(vec2(-0.45, -1.0)));
        float l = bevelStrength * band * lit;
        if (l > 0.0)
            bodyc = over(vec4(highlightColor.rgb * l, l), bodyc);
        else
            bodyc.rgb *= 1.0 + l * 1.4;
    }

    // Refraction: a thin caustic just inside the bevel and a faint colour
    // split along it (simulated; the backdrop itself can't be sampled).
    if (refraction > 0.0) {
        float w = max(bevel, 2.0);
        float caustic = exp(-pow((-d - w * 1.15) / max(w * 0.18, 0.8), 2.0)) * inside;
        float ca = refraction * 0.22 * caustic;
        bodyc = over(vec4(highlightColor.rgb * ca, ca), bodyc);
        float edge = (1.0 - smoothstep(0.0, w * 0.8, -d)) * inside;
        float fa = refraction * 0.30 * edge;
        bodyc = over(vec4(aurora(around) * fa, fa), bodyc);
    }

    outc = over(bodyc * inside, outc);

    // Prism glow outside the rim.
    if (glow > 0.0) {
        float g = glow * 0.55 * exp(-max(d, 0.0) / 7.0) * smoothstep(-aa, aa, d);
        outc = over(vec4(aurora(around + 0.12) * g, g), outc);
    }

    // Inner rim, brighter at the top (light from above).
    if (borderWidth > 0.0) {
        float e = inside * (1.0 - smoothstep(borderWidth - aa * 0.5, borderWidth + aa * 0.5, -d));
        float w = mix(1.0, 1.0 - edgeTopBias, t);
        float ea = innerBorder.a * e * w;
        outc = over(vec4(innerBorder.rgb * ea, ea), outc);
    }

    // Compositor blur follows this surface's alpha (ignore_alpha = blurMask):
    // keep the body above the threshold and the shadow, glow and outer hairline
    // below it, so the blur has exactly the glass's rounded shape.
    if (blurMask > 0.0) {
        if (inside < 0.5) {
            float cap = blurMask * 0.92;
            if (outc.a > cap)
                outc *= cap / outc.a;
        } else if (outc.a < blurMask * 1.1) {
            float k = (blurMask * 1.1 - outc.a) / max(1.0 - outc.a, 1e-4);
            outc += vec4(tint.rgb * k, k) * (1.0 - outc.a);
        }
    }

    fragColor = outc * qt_Opacity;
}
