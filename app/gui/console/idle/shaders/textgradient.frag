#version 440
// Texte rempli d'un dégradé vertical (`background-clip: text`) : la couleur va de `topColor`
// à `bottomColor` sur la hauteur de la boîte, l'alpha vient du texte.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 topColor;
    vec4 bottomColor;
    float boxTop;      // fraction de la hauteur de la source où commence le dégradé
    float boxBottom;   // … et où il finit
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float t = clamp((qt_TexCoord0.y - boxTop) / (boxBottom - boxTop), 0.0, 1.0);
    vec4 c = mix(topColor, bottomColor, t);
    fragColor = vec4(c.rgb, 1.0) * texture(source, qt_TexCoord0).a * qt_Opacity;
}
