#version 440
// Fond CocoOS (BackdropLayer), en un passage : l'art du jeu déjà flouté (une petite
// texture, floutée une fois), cadré comme `inset: -100px` puis zoomé et décalé (dérive
// lente cocoBgPan), légèrement saturé (saturate 1.1), assombri par le vignettage radial
// (ellipse à 50 % 40 %, farthest-corner) et grainé à 7 % en mode « overlay ».
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // taille de l'élément, px du canevas
    float inset;      // débord de l'image autour de l'écran (100)
    float zoom;       // échelle de l'image, autour du centre
    vec2 offset;      // décalage de l'image après zoom, px
    float vignetteIn;   // opacité du noir au centre du vignettage (0,25)
    float vignetteOut;  // …à 75 % du rayon et au-delà (0,85)
    float vignette;   // 1 : vignettage ; 0 : aucun (lancement)
    float grain;      // intensité du grain (0,07)
    float grainSize;  // côté de la texture de grain, px
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D noise;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = size * 0.5;
    vec2 q = (p - c - offset) / zoom + c;
    vec3 col = texture(source, (q + inset) / (size + 2.0 * inset)).rgb;
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = max(mix(vec3(luma), col, 1.1), 0.0);

    // radial-gradient(ellipse at 50% 40%) : rayons de « farthest-side » (au rapport près),
    // agrandis pour passer par le coin le plus loin.
    vec2 center = vec2(0.5, 0.4) * size;
    vec2 side = max(center, size - center);
    vec2 radius = side * sqrt(2.0);
    float t = length((p - center) / radius);
    float shade = mix(vignetteIn, vignetteOut, clamp(t / 0.75, 0.0, 1.0)) * vignette;
    col *= 1.0 - shade;

    float n = texture(noise, fract(p / grainSize)).r;
    vec3 over = mix(2.0 * col * n, 1.0 - 2.0 * (1.0 - col) * (1.0 - n), step(0.5, col));
    col = mix(col, over, grain);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
