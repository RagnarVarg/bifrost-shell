#version 440
// Bifrost prism: a restrained refraction look for selected / active / focus.
// The fill leans slightly toward three desaturated "aurora" stops along an
// angle, a soft split-light caustic sits under the top edge, and the rim
// shifts hue around the perimeter like light through a glass edge.
// mode 0 = fill + rim, mode 1 = rim only (focus ring).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    vec4 baseColor;
    float baseOpacity;
    float intensity;
    vec4 stop0;
    vec4 stop1;
    vec4 stop2;
    float angle;        // degrees
    float spread;
    float tintAmount;
    float caustic;
    float edge;
    float edgeWidth;
    float dispersion;
    float phase;        // 0..1, drift
    float mode;
};

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 aurora(float s) {
    s = fract(s);
    // stop0 → stop1 → stop2 → stop0, smooth
    float x = s * 3.0;
    vec3 a = stop0.rgb, b = stop1.rgb, c = stop2.rgb;
    if (x < 1.0) return mix(a, b, smoothstep(0.0, 1.0, x));
    if (x < 2.0) return mix(b, c, smoothstep(0.0, 1.0, x - 1.0));
    return mix(c, a, smoothstep(0.0, 1.0, x - 2.0));
}

vec4 over(vec4 src, vec4 dst) {
    return src + dst * (1.0 - src.a);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 half_ = itemSize * 0.5;
    vec2 p = px - half_;
    float r = min(radius, min(half_.x, half_.y));
    float d = sdRoundBox(p, half_ - 0.5, r);
    float aa = max(fwidth(d), 0.75);
    float inside = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, d);
    float t = clamp(px.y / max(itemSize.y, 1.0), 0.0, 1.0);

    float rad = radians(angle);
    vec2 dir = vec2(cos(rad), sin(rad));
    vec2 uv = qt_TexCoord0 - 0.5;
    float s = dot(uv, dir) * spread + 0.5 + phase;

    vec4 outc = vec4(0.0);

    if (mode < 0.5) {
        // Intensity drives how much aurora colour, how dense the fill and how
        // strong the inner glow is, so the setting reads clearly from 0 to 3.
        vec3 col = mix(baseColor.rgb, aurora(s), clamp(tintAmount * intensity * 1.4, 0.0, 1.0));
        float a = clamp(baseOpacity * (1.0 + intensity * 0.9), 0.0, 0.85);
        outc = vec4(col * a, a) * inside;

        // Inner aurora glow along the rim.
        float g = clamp(intensity * 0.22, 0.0, 0.6) * exp(-max(-d, 0.0) / 5.0) * inside;
        outc = over(vec4(aurora(atan(p.y, p.x) / 6.28318 + 0.5 + phase) * g, g), outc);

        // Caustic: faint split light just under the top edge.
        float c = caustic * intensity * exp(-pow((-d) / 2.2, 2.0)) * (1.0 - smoothstep(0.0, 0.5, t));
        vec3 cc = aurora(s + 0.33);
        outc = over(vec4(cc * c, c) * inside, outc);
    }

    // Rim: hue shifts around the perimeter; stronger at the top.
    float w = max(edgeWidth, 0.5) * (1.0 + clamp(intensity, 0.0, 3.0) * 0.35);
    float ring = inside * (1.0 - smoothstep(w - aa * 0.5, w + aa * 0.5, -d));
    float around = atan(p.y, p.x) / 6.28318 + 0.5;
    vec3 rc = mix(baseColor.rgb, aurora(around * dispersion + phase), clamp(intensity, 0.0, 1.0));
    float ra = clamp(edge * intensity, 0.0, 1.0) * ring * mix(1.0, 0.45, t);
    if (mode > 0.5)
        ra = max(ra, baseOpacity * ring);
    outc = over(vec4(rc * ra, ra), outc);

    fragColor = outc * qt_Opacity;
}
