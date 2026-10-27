#version 440
// Fond des écrans de veille en un passage : couche floue (déjà rendue) placée par
// `uvScale` / `uvOffset` (son animation de pan), saturation, vignettage elliptique, puis
// grain en fusion « overlay » (sans effet sur le noir : l'OLED reste éteint).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;            // px de référence (1280 × 720)
    vec2 uvScale;         // uv de la couche floue = q * uvScale + uvOffset (q en px de référence)
    vec2 uvOffset;
    float layerOpacity;
    float saturation;
    vec2 vignetteCenter;  // px
    vec2 vignetteRadii;   // px ; x = 0 : pas de vignettage
    float vignetteInner;  // alpha du noir au centre
    float vignetteOuter;  // … à vignetteStop du rayon, et au-delà
    float vignetteStop;
    float grainOpacity;
    float grainTile;      // px de référence par tuile
};
layout(binding = 1) uniform sampler2D blurred;
layout(binding = 2) uniform sampler2D grain;

void main() {
    vec2 q = qt_TexCoord0 * size;
    vec2 uv = q * uvScale + uvOffset;
    vec4 c = vec4(0.0);
    if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0)
        c = texture(blurred, uv) * layerOpacity;
    // Sur fond noir, la couleur prémultipliée est la couleur finale.
    vec3 rgb = c.rgb;
    float s = saturation;
    rgb = clamp(mat3(0.213 + 0.787 * s, 0.213 - 0.213 * s, 0.213 - 0.213 * s,
                     0.715 - 0.715 * s, 0.715 + 0.285 * s, 0.715 - 0.715 * s,
                     0.072 - 0.072 * s, 0.072 - 0.072 * s, 0.072 + 0.928 * s) * rgb, 0.0, 1.0);
    if (vignetteRadii.x > 0.0) {
        float d = length((q - vignetteCenter) / vignetteRadii);
        rgb *= 1.0 - mix(vignetteInner, vignetteOuter, clamp(d / vignetteStop, 0.0, 1.0));
    }
    float g = texture(grain, fract(q / grainTile)).r;
    vec3 overlay = mix(2.0 * rgb * g, 1.0 - 2.0 * (1.0 - rgb) * (1.0 - g), step(0.5, rgb));
    rgb = mix(rgb, overlay, grainOpacity);
    fragColor = vec4(rgb, 1.0) * qt_Opacity;
}
