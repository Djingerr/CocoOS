#version 440
// Une jaquette du carrousel CocoOS (CoverFlow), en un passage : l'image aux coins
// arrondis, le reflet en biais (gloss 135°), le dégradé bas des jaquettes latérales,
// l'assombrissement (brightness) et le balayage de la jaquette centrale (cocoSheen) ;
// tant que l'image charge, un squelette de verre et son balayage (cocoShimmer). Avec
// `mirror`, le reflet au sol : le bas de l'image retourné, qui s'efface en descendant.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 coverSize;   // taille de la jaquette, px
    float itemHeight; // hauteur de l'élément (la jaquette, ou la bande du reflet)
    float radius;
    float dim;        // 1 − brightness
    float gloss;      // reflet en biais (0,12)
    float shade;      // dégradé bas (0,55 sur une latérale)
    float ring;       // filet clair du bord (0,12 au centre)
    float sheen;      // balayage : position de la bande, en largeurs de bande
    float shimmer;    // squelette : position de la bande, idem
    float reveal;     // 0 : squelette ; 1 : image
    float zoom;       // échelle de l'image à son apparition (1,04 → 1)
    float blurPx;     // flou de l'image à son apparition (8 → 0)
    float mirror;     // 1 : reflet au sol
    float mirrorAlpha;  // opacité du reflet contre la jaquette (0,24)
    float mirrorSpan;   // part de la hauteur sur laquelle il s'efface (0,18)
};
layout(binding = 1) uniform sampler2D source;

float roundedAlpha(vec2 p) {
    vec2 c = coverSize * 0.5;
    vec2 q = abs(p - c) - (c - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    return clamp(0.5 - d, 0.0, 1.0);
}

vec4 picture(vec2 uv) {
    uv = (uv - 0.5) / zoom + 0.5;
    if (blurPx < 0.01)
        return texture(source, uv);
    vec2 step = blurPx / coverSize;
    vec4 sum = vec4(0.0);
    for (int x = -1; x <= 1; x++)
        for (int y = -1; y <= 1; y++)
            sum += texture(source, uv + vec2(x, y) * step);
    return sum / 9.0;
}

// Bande claire de 30 % (ou 45 %) de la largeur, inclinée de `skew`, à `pos` largeurs de bande.
float band(vec2 p, float width, float pos, float skew, float peak) {
    float u = (p.x - pos * width + skew * (p.y - coverSize.y * 0.5)) / width;
    return peak * clamp(1.0 - abs(2.0 * u - 1.0), 0.0, 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(coverSize.x, itemHeight);
    vec4 col;
    float alpha;
    if (mirror > 0.5) {
        // La bande sous la jaquette montre son bas, retourné ; la forme est celle de la
        // jaquette retournée (coins arrondis en haut de la bande).
        vec2 q = vec2(p.x, coverSize.y - p.y);
        alpha = roundedAlpha(q) * mirrorAlpha * clamp(1.0 - p.y / (mirrorSpan * coverSize.y), 0.0, 1.0);
        col = picture(q / coverSize) * reveal;
    } else {
        alpha = roundedAlpha(p);
        // Squelette : verre blanc à 7 % et son balayage ; l'image le recouvre en fondu.
        vec4 skeleton = vec4(0.07 + band(p, 0.45 * coverSize.x, shimmer, 0.213, 0.09));
        col = mix(skeleton, picture(p / coverSize), reveal);
        float t = (p.x + p.y) / (coverSize.x + coverSize.y);
        col.rgb = mix(col.rgb, vec3(col.a), gloss * reveal * clamp(1.0 - t / 0.45, 0.0, 1.0));
        col.rgb *= 1.0 - shade * clamp(1.0 - (coverSize.y - p.y) / (0.48 * coverSize.y), 0.0, 1.0);
        col.rgb = mix(col.rgb, vec3(col.a), band(p, 0.3 * coverSize.x, sheen, 0.325, 0.16));
        vec2 c = coverSize * 0.5;
        vec2 e = abs(p - c) - (c - radius);
        float d = length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - radius;
        col.rgb = mix(col.rgb, vec3(col.a), ring * clamp(1.0 - abs(d + 0.5), 0.0, 1.0));
    }
    col.rgb *= 1.0 - dim;
    fragColor = col * alpha * qt_Opacity;
}
