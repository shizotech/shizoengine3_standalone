// ==== Force2Colors / helpers ================================================
// Alles was aus einem beliebigen RGBA-Pixel eine einzelne 0..1 Maske macht,
// plus die Dither-Matrizen fuer die harte Schwelle.

const float C2_GAMMA = 2.2;
const vec3  C2_LUMA  = vec3(0.2126, 0.7152, 0.0722);
const float C2_INV_SQRT3 = 0.57735027;

// Perzeptuelle Helligkeit (linearisiert -> gewichtet -> zurueck nach sRGB).
float c2_luma(vec3 c) {
    vec3 lin = pow(max(c, 0.0), vec3(C2_GAMMA));
    return pow(max(dot(lin, C2_LUMA), 0.0), 1.0 / C2_GAMMA);
}

vec3 c2_rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// ---- Quelle der Trennung ---------------------------------------------------
// mode:
//  0 Luma | 1 Average | 2 MaxChannel | 3 MinChannel | 4 Saturation
//  5 Hue  | 6 ColorDistance (zu ref) | 7 Red | 8 Green | 9 Blue | 10 Alpha
float c2_source(vec3 rgb, float a, int mode, vec3 ref) {
    vec3 c = clamp(rgb, 0.0, 1.0);
    if (mode == 1)  return (c.r + c.g + c.b) / 3.0;
    if (mode == 2)  return max(c.r, max(c.g, c.b));
    if (mode == 3)  return min(c.r, min(c.g, c.b));
    if (mode == 4)  return c2_rgb2hsv(c).y;
    if (mode == 5)  return c2_rgb2hsv(c).x;
    if (mode == 6)  return 1.0 - clamp(length(c - clamp(ref, 0.0, 1.0)) * C2_INV_SQRT3, 0.0, 1.0);
    if (mode == 7)  return c.r;
    if (mode == 8)  return c.g;
    if (mode == 9)  return c.b;
    if (mode == 10) return clamp(a, 0.0, 1.0);
    return c2_luma(c);
}

// ---- Dither ----------------------------------------------------------------
// Ordered-Bayer per Rekursion (klassischer GLSL-Trick), Rueckgabe 0..~1.
float c2_bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x * 0.5 + a.y * a.y * 0.75);
}
float c2_bayer4(vec2 a) { return c2_bayer2(a * 0.5) * 0.25 + c2_bayer2(a); }
float c2_bayer8(vec2 a) { return c2_bayer4(a * 0.5) * 0.25 + c2_bayer2(a); }

float c2_hash12(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Interleaved Gradient Noise - feiner und ruhiger als weisses Rauschen.
float c2_ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// mode: 0 Off | 1 Bayer8 | 2 Bayer4 | 3 IGN | 4 WhiteNoise
// Rueckgabe zentriert um 0 (-0.5 .. 0.5), damit sie direkt auf die Maske
// addiert werden kann ohne die mittlere Helligkeit zu verschieben.
float c2_dither(int mode, vec2 px, float t) {
    if (mode == 1) return c2_bayer8(px) * 1.015873 - 0.5;
    if (mode == 2) return c2_bayer4(px) * 1.066667 - 0.5;
    if (mode == 3) return c2_ign(px + t) - 0.5;
    if (mode == 4) return c2_hash12(px + t) - 0.5;
    return 0.0;
}
