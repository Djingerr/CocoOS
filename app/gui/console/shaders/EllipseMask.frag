#version 440
// Masque elliptique (BootSplash) : efface la source à l'intérieur de l'ellipse, avec
// un bord d'un pixel adouci. Les lettres sortent ainsi de derrière la silhouette du O.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;       // px
    vec2 ellipseCenter;  // px, repère de la source
    vec2 ellipseRadii;   // px
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec2 q = (qt_TexCoord0 * itemSize - ellipseCenter) / ellipseRadii;
    float aa = 1.0 / min(ellipseRadii.x, ellipseRadii.y);
    float m = smoothstep(1.0 - aa, 1.0, length(q));
    fragColor = c * m * qt_Opacity;
}
