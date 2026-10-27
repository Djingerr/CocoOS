#version 440
// Flou gaussien, un passage (horizontal ou vertical selon `texel`). Deux passages = le
// `filter: blur()` CSS. Rendu une fois sur une texture basse résolution : rien ne
// l'anime (seule la couche floue bouge ensuite).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;      // un texel de la source dans la direction du passage (uv)
    float sigma;     // écart type, en texels (≤ 12 : 48 texels = 4 sigma)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 sum = vec4(0.0);
    float total = 0.0;
    for (int i = -48; i <= 48; i++) {
        float x = float(i);
        float w = exp(-0.5 * x * x / (sigma * sigma));
        sum += texture(source, qt_TexCoord0 + x * texel) * w;
        total += w;
    }
    fragColor = sum / total * qt_Opacity;
}
