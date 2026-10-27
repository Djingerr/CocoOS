#version 440
// Jaquette : coins arrondis (bord d'un pixel adouci) et, pour son reflet au sol, un
// fondu vertical (alpha `fadeAlpha` en haut, nul à `fadeEnd` de la hauteur).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // px
    float radius;      // px
    float fadeAlpha;   // 1 : pas de fondu
    float fadeEnd;     // fraction de la hauteur ; 0 : pas de fondu
    float pixel;       // px de l'item par pixel d'écran (bord adouci)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 d = abs(p - itemSize * 0.5) - (itemSize * 0.5 - radius);
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
    float a = clamp(0.5 - dist / pixel, 0.0, 1.0);
    if (fadeEnd > 0.0)
        a *= fadeAlpha * clamp(1.0 - qt_TexCoord0.y / fadeEnd, 0.0, 1.0);
    fragColor = texture(source, qt_TexCoord0) * a * qt_Opacity;
}
