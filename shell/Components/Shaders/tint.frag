#version 440
// Recolours a monochrome (white) icon: keeps its alpha, replaces its colour.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float a = texture(source, qt_TexCoord0).a * color.a;
    fragColor = vec4(color.rgb * a, a) * qt_Opacity;
}
