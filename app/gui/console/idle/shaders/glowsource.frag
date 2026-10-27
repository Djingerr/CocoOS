#version 440
// Lueur de l'écran 12 avant flou : `radial-gradient(ellipse, accent 0%, transparent 65%)`
// sur une boîte (taille `radii` farthest-corner), en alpha prémultiplié.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 canvasSize;   // px de référence
    vec2 center;       // px de référence, repère de la toile
    vec2 radii;        // rayons du dégradé (farthest-corner)
    float stopAt;      // transparent à cette fraction du rayon
    vec4 color;
};

void main() {
    float d = length((qt_TexCoord0 * canvasSize - center) / radii);
    float a = clamp(1.0 - d / stopAt, 0.0, 1.0);
    fragColor = vec4(color.rgb, 1.0) * a * qt_Opacity;
}
