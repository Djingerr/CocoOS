#version 440
// Masque angulaire du O (BootSplash) : ne garde de la source que la portion de tour
// [startAngle, startAngle + len·2π], adoucie au bout (featherHead) et, pour le
// chargeur, au départ (featherTail). Angles en radians, 0 = droite, sens horaire.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;        // centre du O, coordonnées normalisées de la source
    vec2 itemSize;      // taille de la source en px (angle non déformé)
    float startAngle;
    float len;          // fraction de tour révélée [0..1]
    float featherHead;  // fraction de tour
    float featherTail;  // 0 = départ net (tracé), > 0 pour le chargeur
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec2 d = (qt_TexCoord0 - center) * itemSize;
    float u = fract((atan(d.y, d.x) - startAngle) / 6.28318530718);
    float m = 1.0;
    if (len < 0.999) {
        float head = 1.0 - smoothstep(len - featherHead, len, u);
        float tail = featherTail > 0.0 ? smoothstep(0.0, featherTail, u) : 1.0;
        m = head * tail;
    }
    fragColor = c * m * qt_Opacity;
}
