// --- Prism: the code every pass includes ---
// ---- Prism: glass shapes that bend and split light (passes L and A), the music, the glitch ----
#define SPRING_STIFF 40.0
#define SPRING_DAMP 6.0

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float PI  = 3.14159265358979;
const float TAU = 6.28318530717959;

// ---- shader-skills library: hash ----
// PCG-style 1D integer hash.
uint pcgHash(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
// 3D integer hash, three decorrelated outputs.
uvec3 pcg3d(uvec3 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> 16u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}
// Map a uint to [0,1) using the top 24 bits, so the result can never round up to 1.0.
float uintToUnit(uint h) { return float(h >> 8u) * (1.0 / 16777216.0); }
vec2 uintToUnit(uvec2 h) { return vec2(h >> 8u) * (1.0 / 16777216.0); }
vec3 uintToUnit(uvec3 h) { return vec3(h >> 8u) * (1.0 / 16777216.0); }
vec4 uintToUnit(uvec4 h) { return vec4(h >> 8u) * (1.0 / 16777216.0); }
// Random float in [0,1) for an integer-valued 2D input.
float hash12(vec2 p) {
    uvec2 q = uvec2(ivec2(floor(p)));
    return uintToUnit(pcgHash(q.x + pcgHash(q.y)));
}
// Random float in [0,1) for an integer-valued 3D input.
float hash13(vec3 p) {
    uvec3 q = uvec3(ivec3(floor(p)));
    return uintToUnit(pcgHash(q.x + pcgHash(q.y + pcgHash(q.z))));
}
// Random vec2 in [0,1)^2 for an integer-valued 2D input.
vec2 hash22(vec2 p) {
    ivec2 q = ivec2(floor(p));
    return uintToUnit(pcg3d(uvec3(q.x, q.y, 0x2545u))).xy;
}
// Random vec3 in [0,1)^3 for an integer-valued 3D input.
vec3 hash33(vec3 p) { return uintToUnit(pcg3d(uvec3(ivec3(floor(p))))); }

// ---- shader-skills library: noise ----
// Quintic fade 6t^5 - 15t^4 + 10t^3: C2-continuous interpolation weights for lattice noise.
vec2 quinticFade(vec2 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }
vec3 quinticFade(vec3 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }
// Derivative of quinticFade: 30 t^2 (t - 1)^2.
vec2 quinticFadeDeriv(vec2 f) { return 30.0 * f * f * (f * (f - 2.0) + 1.0); }
vec3 quinticFadeDeriv(vec3 f) { return 30.0 * f * f * (f * (f - 2.0) + 1.0); }
// Unit gradient for a 2D lattice point.
vec2 latticeGradient(vec2 cell) {
    float a = TAU * hash12(cell);
    return vec2(cos(a), sin(a));
}
// 2D gradient (Perlin-style) noise with analytic derivatives. Returns vec3(value, d/dx, d/dy). Gradient noise has less grid-aligned blockiness than value noise. Prefer it for fBm.
vec3 gradientNoiseD(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = quinticFade(f), du = quinticFadeDeriv(f);
    vec2 ga = latticeGradient(i);
    vec2 gb = latticeGradient(i + vec2(1.0, 0.0));
    vec2 gc = latticeGradient(i + vec2(0.0, 1.0));
    vec2 gd = latticeGradient(i + vec2(1.0, 1.0));
    float va = dot(ga, f);
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    float k = va - vb - vc + vd;
    float value = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
    vec2 deriv = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
               + du * (vec2(vb - va, vc - va) + u.yx * k);
    return vec3(value, deriv);
}
// 2D gradient noise.
float gradientNoise(vec2 p) { return gradientNoiseD(p).x; }
// Dot product of a hashed 3D gradient with the offset to its lattice corner.
float latticeGradDot(vec3 cell, vec3 corner, vec3 f) {
    vec3 g = hash33(cell + corner) * 2.0 - 1.0;
    return dot(g, f - corner);
}
// 3D gradient noise.
float gradientNoise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    vec3 u = quinticFade(f);
    return mix(mix(mix(latticeGradDot(i, vec3(0, 0, 0), f), latticeGradDot(i, vec3(1, 0, 0), f), u.x),
                   mix(latticeGradDot(i, vec3(0, 1, 0), f), latticeGradDot(i, vec3(1, 1, 0), f), u.x), u.y),
               mix(mix(latticeGradDot(i, vec3(0, 0, 1), f), latticeGradDot(i, vec3(1, 0, 1), f), u.x),
                   mix(latticeGradDot(i, vec3(0, 1, 1), f), latticeGradDot(i, vec3(1, 1, 1), f), u.x), u.y), u.z);
}
// 3D gradient noise with analytic derivatives. Returns vec4(value, d/dx, d/dy, d/dz); value equals gradientNoise(p). The trilinear blend is expanded as a polynomial in the fade weights, so the gradient is the same blend of the corner gradients plus the chain-rule term of the fade.
vec4 gradientNoiseD(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    vec3 u = quinticFade(f), du = quinticFadeDeriv(f);
    vec3 g000 = hash33(i) * 2.0 - 1.0;
    vec3 g100 = hash33(i + vec3(1, 0, 0)) * 2.0 - 1.0;
    vec3 g010 = hash33(i + vec3(0, 1, 0)) * 2.0 - 1.0;
    vec3 g110 = hash33(i + vec3(1, 1, 0)) * 2.0 - 1.0;
    vec3 g001 = hash33(i + vec3(0, 0, 1)) * 2.0 - 1.0;
    vec3 g101 = hash33(i + vec3(1, 0, 1)) * 2.0 - 1.0;
    vec3 g011 = hash33(i + vec3(0, 1, 1)) * 2.0 - 1.0;
    vec3 g111 = hash33(i + vec3(1, 1, 1)) * 2.0 - 1.0;
    float v000 = dot(g000, f);
    float v100 = dot(g100, f - vec3(1, 0, 0));
    float v010 = dot(g010, f - vec3(0, 1, 0));
    float v110 = dot(g110, f - vec3(1, 1, 0));
    float v001 = dot(g001, f - vec3(0, 0, 1));
    float v101 = dot(g101, f - vec3(1, 0, 1));
    float v011 = dot(g011, f - vec3(0, 1, 1));
    float v111 = dot(g111, f - vec3(1, 1, 1));
    // value = v000 + kx u.x + ky u.y + kz u.z + kxy u.x u.y + kyz u.y u.z + kzx u.z u.x + kxyz u.x u.y u.z
    float kx = v100 - v000, ky = v010 - v000, kz = v001 - v000;
    float kxy = v000 - v100 - v010 + v110;
    float kyz = v000 - v010 - v001 + v011;
    float kzx = v000 - v100 - v001 + v101;
    float kxyz = -v000 + v100 + v010 - v110 + v001 - v101 - v011 + v111;
    float value = v000 + kx * u.x + ky * u.y + kz * u.z
                + kxy * u.x * u.y + kyz * u.y * u.z + kzx * u.z * u.x + kxyz * u.x * u.y * u.z;
    vec3 grad = g000 + (g100 - g000) * u.x + (g010 - g000) * u.y + (g001 - g000) * u.z
              + (g000 - g100 - g010 + g110) * u.x * u.y
              + (g000 - g010 - g001 + g011) * u.y * u.z
              + (g000 - g100 - g001 + g101) * u.z * u.x
              + (-g000 + g100 + g010 - g110 + g001 - g101 - g011 + g111) * u.x * u.y * u.z
              + du * vec3(kx + kxy * u.y + kzx * u.z + kxyz * u.y * u.z,
                          ky + kxy * u.x + kyz * u.z + kxyz * u.x * u.z,
                          kz + kyz * u.y + kzx * u.x + kxyz * u.x * u.y);
    return vec4(value, grad);
}

// ---- shader-skills library: operators ----
// Smooth union (polynomial, C1). Blends where |a - b| < k, with a max bulge of k/4.
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
// Smooth intersection, the mirror of smin.
float smax(float a, float b, float k) { return -smin(-a, -b, k); }

// ---- shader-skills library: camera ----
// Camera-to-world matrix looking from ro toward ta, with roll in radians. Columns are (right, up, forward).
mat3 cameraMatrix(vec3 ro, vec3 ta, float roll) {
    vec3 w = normalize(ta - ro);
    vec3 up = vec3(sin(roll), cos(roll), 0.0);
    vec3 u = normalize(cross(w, up));
    vec3 v = cross(u, w);
    return mat3(u, v, w);
}
// Primary ray direction for screen point uv. focal is about 1.5-2.5 for natural framing (see fovToFocal).
vec3 cameraRay(mat3 cam, vec2 uv, float focal) {
    return normalize(cam * vec3(uv, focal));
}

// ---- shader-skills library: shading ----
// Schlick Fresnel. u is VoH for lights and NoV for environment reflections and rims. f0 = 0.04 for dielectrics (plastic, skin, stone, water ~0.02); for metals f0 = base color.
vec3 fresnelSchlick(float u, vec3 f0) {
    float m = clamp(1.0 - u, 0.0, 1.0);
    float m2 = m * m;
    return f0 + (1.0 - f0) * (m2 * m2 * m);
}

// ---- shader-skills library: water ----
// Exact unpolarized dielectric Fresnel for a positive incident cosine and positive refractive indices. Returns 1 for total internal reflection. Caller chooses etaIncident/etaTransmitted for the ray's side.
float fresnelDielectric(float cosIncident, float etaIncident, float etaTransmitted) {
    float ci = clamp(abs(cosIncident),0.0,1.0);
    float ei = max(etaIncident,0.000001), et = max(etaTransmitted,0.000001);
    if (abs(ei-et)<0.0000001) return 0.0;
    float sinT2 = (ei*ei)/(et*et)*max(0.0,1.0-ci*ci);
    if (sinT2>=1.0) return 1.0;
    float ct = sqrt(max(0.0,1.0-sinT2));
    float rs = (ei*ci-et*ct)/max(ei*ci+et*ct,0.000001);
    float rp = (et*ci-ei*ct)/max(et*ci+ei*ct,0.000001);
    return clamp(0.5*(rs*rs+rp*rp),0.0,1.0);
}

// ---- shader-skills library: color ----
// Exact sRGB decode (EOTF): encoded [0,1] -> linear.
vec3 srgbToLinear(vec3 c) {
    c = max(c, 0.0);
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}
// Exact sRGB encode (OETF): linear -> display [0,1]. Apply exactly once, after tonemapping. pow(c, 1/2.2) is visibly wrong near black (0.001 encodes to 0.013 here vs 0.043 with 2.2).
vec3 linearToSrgb(vec3 c) {
    c = max(c, 0.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

// ---- shader-skills library: tonemap ----
// AgX: log encoding plus a sigmoid inside an inset/outset gamut. Mid-grey 0.18 maps to about 0.5 display. Minimal implementation after Troy Sobotka's AgX and Benjamin Wrensch's polynomial fit (both MIT).
vec3 tonemapAgX(vec3 c) {
    const mat3 inset = mat3(0.842479062253094, 0.0423282422610123, 0.0423756549057051,
                            0.0784335999999992, 0.878468636469772, 0.0784336,
                            0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    const mat3 outset = mat3(1.19687900512017, -0.0528968517574562, -0.0529716355144438,
                             -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
                             -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    const float minEv = -12.47393, maxEv = 4.026069;
    c = inset * max(c, 0.0);
    c = clamp((log2(max(c, 1e-10)) - minEv) / (maxEv - minEv), 0.0, 1.0);
    vec3 x2 = c * c, x4 = x2 * x2;
    c = 15.5 * x4 * x2 - 40.14 * x4 * c + 31.96 * x4 - 6.868 * x2 * c + 0.4298 * x2 + 0.1191 * c - 0.00232;
    c = outset * c;
    return pow(max(c, 0.0), vec3(2.2));
}
// AgX with the "punchy" look (more contrast and saturation) for stylized art.
vec3 tonemapAgXPunchy(vec3 c) {
    const mat3 inset = mat3(0.842479062253094, 0.0423282422610123, 0.0423756549057051,
                            0.0784335999999992, 0.878468636469772, 0.0784336,
                            0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    const mat3 outset = mat3(1.19687900512017, -0.0528968517574562, -0.0529716355144438,
                             -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
                             -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    const float minEv = -12.47393, maxEv = 4.026069;
    c = inset * max(c, 0.0);
    c = clamp((log2(max(c, 1e-10)) - minEv) / (maxEv - minEv), 0.0, 1.0);
    vec3 x2 = c * c, x4 = x2 * x2;
    c = 15.5 * x4 * x2 - 40.14 * x4 * c + 31.96 * x4 - 6.868 * x2 * c + 0.4298 * x2 + 0.1191 * c - 0.00232;
    c = pow(max(c, 0.0), vec3(1.35));
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = luma + 1.4 * (c - luma);
    c = outset * c;
    return pow(max(c, 0.0), vec3(2.2));
}
// Khronos PBR Neutral: leaves [0, ~0.76] almost untouched and compresses only highlights, preserving hue.
vec3 tonemapNeutral(vec3 c) {
    const float startCompression = 0.76;
    const float desaturation = 0.15;
    c = max(c, 0.0);
    float x = min(c.r, min(c.g, c.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    c -= offset;
    float peak = max(c.r, max(c.g, c.b));
    if (peak < startCompression) return c;
    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    c *= newPeak / peak;
    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(c, vec3(newPeak), g);
}
// Stephen Hill's ACES fit (RRT + ODT, sRGB primaries). Contrasty and saturated; blues drift purple when very bright. Darker than AgX at the same exposure: multiply the input by about 1.6 to compensate.
vec3 tonemapACES(vec3 c) {
    c = max(c, 0.0) * mat3(0.59719, 0.35458, 0.04823,
                           0.07600, 0.90834, 0.01566,
                           0.02840, 0.13383, 0.83777);
    c = (c * (c + 0.0245786) - 0.000090537) / (c * (0.983729 * c + 0.4329510) + 0.238081);
    c = c * mat3(1.60475, -0.53108, -0.07367,
                 -0.10208, 1.10813, -0.00605,
                 -0.00327, -0.07276, 1.07602);
    return clamp(c, 0.0, 1.0);
}

// ---- shader-skills library: post ----
// Signal-dependent film grain: noise grows with sqrt(intensity), as photon noise does. n should be zero-mean noise (e.g. hash13(vec3(fragCoord, iFrame)) * 2 - 1). Apply in linear HDR before tonemapping.
vec3 filmGrain(vec3 col, float amount, float n) {
    return col + amount * sqrt(max(col, 0.0)) * n;
}
// Triangular-PDF dither of +-1 LSB for 8-bit output. Add AFTER linearToSrgb, right before writing fragColor.
vec3 ditherTPDF(vec2 fragCoord, int frame) {
    vec2 r = hash22(vec2(floor(fragCoord) + 7919.0 * float(frame % 1024)));
    return vec3((r.x + r.y - 1.0) / 255.0);
}

// ---- shader-skills library: debug ----
// Normal as RGB.
vec3 debugNormal(vec3 n) { return 0.5 + 0.5 * n; }
// Heat ramp for a value in [0,1]: black, blue, magenta, orange, yellow, white.
vec3 debugHeat(float t) {
    t = clamp(t, 0.0, 1.0);
    return clamp(vec3(1.5 * t, 1.6 * t * t * t - 0.1, 0.9 * sin(PI * t) + 0.2 * t * t), 0.0, 1.0);
}

// ---- Prism: the glass shapes (signed distance functions), the grid of copies, the index of refraction per
// wavelength and the light beam (passes L and A) ----
#define SPRING_STIFF 40.0
#define SPRING_DAMP 6.0

//@enum options=(Prism, Pyramid, Cube, Gem, Shards, Sphere, Torus, Capsule, Octahedron, Dodecahedron, Icosahedron, Twisted box, Knot, Blob, Heart, Star, Lens, Drop) value=0
uniform int shape;                  // Gem: a round brilliant; Shards: five thin glass fragments; Blob: drops that melt into each other
//@enum options=(Prism, Pyramid, Cube, Gem, Shards, Sphere, Torus, Capsule, Octahedron, Dodecahedron, Icosahedron, Twisted box, Knot, Blob, Heart, Star, Lens, Drop) value=5
uniform int morph_shape;            // the shape Morph turns it into
//@slider min=0.0 max=1.0 value=0.0
uniform float morph;                // 0: Shape, 1: Morph shape; in between both are traced (twice the cost)
//@slider min=0.0 max=64.0 value=0.0
uniform float morph_cycle;          // beats for Shape -> Morph shape -> Shape by itself; 0: off
//@slider min=0.4 max=2.0 value=1.0
uniform float size;
//@slider min=0.2 max=3.0 value=1.5
uniform float depth;                // Prism: how long it is (along its axis); Heart, Star: how thick
//@slider min=-2.0 max=2.0 value=0.0
uniform float spin;                 // turns per 16 beats around its axis (the axis looks at the camera)
//@slider min=0.0 max=30.0 value=4.0
uniform float rock;                 // degrees it rocks to and fro over 8 beats (and with the mids of the music)
//@slider min=-90.0 max=90.0 value=0.0
uniform float turn;                 // degrees around its axis at rest
//@slider min=-2.0 max=2.0 value=0.25
uniform float tumble;               // turns per 16 beats around the vertical: shows its sides
//@slider min=-90.0 max=90.0 value=30.0
uniform float tilt;                 // degrees around the vertical at rest
//@slider min=-2.0 max=2.0 value=0.0
uniform float twist;                // turns the shape twists over its height
//@slider min=0.0 max=0.5 value=0.06
uniform float pump;                 // how much the bass and the kicks make it bigger
//@enum options=(Crown glass, Flint glass, Fused silica, Diamond, Custom) value=0
uniform int glass;                  // the index of refraction per wavelength (Sellmeier): flint and diamond bend and split more
//@slider min=1.0 max=2.6 value=1.5
uniform float ior;                  // Glass Custom: the index of refraction (yellow light); its colours split like flint glass
//@slider min=0.0 max=12.0 value=6.0
uniform float dispersion;           // how far the colours split: 1 is the real glass, 0 no rainbow
//@rgb value=(0.92, 0.97, 1.0)
uniform vec3 glass_tint;
//@slider min=0.0 max=2.0 value=0.1
uniform float absorption;           // light the glass swallows on its way through (Beer-Lambert): thick parts get the colour of Glass tint

//@int min=1 max=6 value=1
uniform int count_x;                // copies side by side (1: one object)
//@int min=1 max=6 value=1
uniform int count_y;                // rows of copies
//@slider min=1.0 max=4.0 value=1.6
uniform float spacing;              // distance between the copies, in sizes (below about 1.6 big shapes get cut at the edge of their cell)
//@slider min=0.0 max=180.0 value=25.0
uniform float instance_rotation;    // degrees each copy is turned more than the one before
//@slider min=0.0 max=1.0 value=0.35
uniform float instance_variation;   // each copy tilted and spinning a little its own way
//@slider min=0.0 max=1.0 value=0.0
uniform float shape_variation;      // the share of copies that take another shape, picked at random

//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 beam_color;
//@slider min=0.0 max=30.0 value=0.0
uniform float beam_intensity;       // the white beam the glass splits into a rainbow (8 and Environment Studio, Backdrop None: the album cover)
//@slider min=0.003 max=0.15 value=0.022
uniform float beam_width;
//@slider min=-60.0 max=60.0 value=0.0
uniform float beam_angle;           // degrees: Prism: away from the path of least bending (0), the others: how steep it rises
//@slider min=-60.0 max=60.0 value=0.0
uniform float beam_direction;       // degrees the beam comes from, around the prism (0: from the left)
//@slider min=-0.6 max=0.6 value=0.0
uniform float beam_offset;          // where it hits: up or down on the glass, part of the size
//@slider min=0.0 max=0.08 value=0.012
uniform float spread;               // how much each colour of the fan widens as it travels
//@slider min=0.0 max=1.0 value=0.7
uniform float beat_flash;           // the music makes the beam brighter

const int FAN = 32;                 // the rays of the rainbow fan (pass L: one column each)
const int SEGS = 7;                 // points of a ray's path (pass L: rows 0 .. 6; row 7 the wavelength and count)
const int NSHAPES = 18;

mat3 rotX(float a) { return mat3(1.0, 0.0, 0.0, 0.0, cos(a), sin(a), 0.0, -sin(a), cos(a)); }
mat3 rotY(float a) { return mat3(cos(a), 0.0, -sin(a), 0.0, 1.0, 0.0, sin(a), 0.0, cos(a)); }
mat3 rotZ(float a) { return mat3(cos(a), sin(a), 0.0, -sin(a), cos(a), 0.0, 0.0, 0.0, 1.0); }

// ---- set by setupScene() ----
float gTime;
float gS;                           // the size now (with Pump)
float gSpinA;                       // the angle around the axis now (Spin, Rock, Turn, the mids)
float gTumbleA;                     // the angle around the vertical now
float gMorph;
float gTwist;                       // radians per unit of height
ivec2 gN;                           // copies in x and y
float gCell;                        // the size of a cell of the grid
vec3 gHalf;                         // half the size of the box around all copies
float floorY;
mat3 SH_R[5];                       // Shards: the turn, the middle, the three edges and the thickness of each
vec3 SH_C[5];
vec4 SH_N[5];                       // (edge 0 normal, edge 1 normal)
vec4 SH_M[5];                       // (edge 2 normal, -, -)
vec4 SH_D[5];                       // (edge distances 0, 1, 2, half the thickness)
vec4 BL[5];                         // Blob: the drops (middle, radius)

// ---- the cell a ray is in (the copy it looks at) ----
ivec2 cId = ivec2(-100);
mat3 cRot;
vec3 cCenter;
int cShape;
float gStepK = 0.9;                 // the march steps by this share of the distance (shapes whose distance is not exact)

// ---- the shapes, in the space of the object, about 1.2 sizes across ----
float sdEqTri(vec2 p, float r) {
    // an equilateral triangle, apex up, r half its side (after Inigo Quilez, MIT)
    const float k = 1.7320508;
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0)
        p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}
// A 2D distance pulled out along z to half the thickness h, its edges rounded by rr
float extrudeR(float d2, float z, float h, float rr) {
    vec2 w = vec2(d2 + rr, abs(z) - h + rr);
    return min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - rr;
}
float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}
float sdPyramid(vec3 p, float h) {
    // base 1 x 1 at y = 0, apex at y = h (after Inigo Quilez, MIT)
    float m2 = h * h + 0.25;
    p.xz = abs(p.xz);
    p.xz = (p.z > p.x) ? p.zx : p.xz;
    p.xz -= 0.5;
    vec3 q = vec3(p.z, h * p.y - 0.5 * p.x, h * p.x + 0.5 * p.y);
    float s = max(-q.x, 0.0);
    float t = clamp((q.y - 0.5 * p.z) / (m2 + 0.25), 0.0, 1.0);
    float a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
    float b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);
    float d2 = min(q.y, -q.x * m2 - q.y * 0.5) > 0.0 ? 0.0 : min(a, b);
    return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -p.y));
}
float sdOctahedron(vec3 p, float s) {
    // exact (after Inigo Quilez, MIT)
    p = abs(p);
    float m = p.x + p.y + p.z - s;
    vec3 q;
    if (3.0 * p.x < m)
        q = p.xyz;
    else if (3.0 * p.y < m)
        q = p.yzx;
    else if (3.0 * p.z < m)
        q = p.zxy;
    else
        return m * 0.57735027;
    float k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
    return length(vec3(q.x, q.y - s + k, q.z - k));
}
// Dodecahedron and icosahedron: the largest distance to their face planes (generalized distance functions,
// Akleman / hg_sdf)
const float PHI = 1.618034;
float sdDodeca(vec3 p, float r) {
    p = abs(p);
    vec3 a = normalize(vec3(0.0, PHI, 1.0)), b = normalize(vec3(1.0, 0.0, PHI)), c = normalize(vec3(PHI, 1.0, 0.0));
    vec3 a2 = normalize(vec3(0.0, -PHI, 1.0)), b2 = normalize(vec3(-1.0, 0.0, PHI)), c2 = normalize(vec3(-PHI, 1.0, 0.0));
    float d = max(max(abs(dot(p, a)), abs(dot(p, b))), abs(dot(p, c)));
    d = max(d, max(max(abs(dot(p, a2)), abs(dot(p, b2))), abs(dot(p, c2))));
    return d - r;
}
float sdIcosa(vec3 p, float r) {
    p = abs(p);
    float d = dot(p, vec3(0.57735027));
    vec3 a = normalize(vec3(0.0, 1.0, PHI + 1.0)), b = normalize(vec3(PHI + 1.0, 0.0, 1.0)), c = normalize(vec3(1.0, PHI + 1.0, 0.0));
    vec3 a2 = normalize(vec3(0.0, -1.0, PHI + 1.0)), b2 = normalize(vec3(-PHI - 1.0, 0.0, 1.0)), c2 = normalize(vec3(-1.0, PHI + 1.0, 0.0));
    d = max(d, max(max(abs(dot(p, a)), abs(dot(p, b))), abs(dot(p, c))));
    d = max(d, max(max(abs(dot(p, a2)), abs(dot(p, b2))), abs(dot(p, c2))));
    d = max(d, max(abs(dot(p, normalize(vec3(-1.0, 1.0, 1.0)))), max(abs(dot(p, normalize(vec3(1.0, -1.0, 1.0)))), abs(dot(p, normalize(vec3(1.0, 1.0, -1.0)))))));
    return d - r;
}
// A round brilliant, table up: girdle, table, 8 crown and 8 pavilion main facets and the facets between them
float sdGem(vec3 p, float R) {
    p.y -= 0.28 * R;
    float r = length(p.xz);
    float a = atan(p.z, p.x);
    const float SEC = 0.785398163;
    float a1 = mod(a, SEC) - 0.5 * SEC;
    float a2 = mod(a + 0.5 * SEC, SEC) - 0.5 * SEC;
    float x1 = r * cos(a1), x2 = r * cos(a2);
    float g = 0.02 * R;
    float d = r - R;
    d = max(d, p.y - (g + 0.296 * R));
    d = max(d, dot(vec2(x1 - R, p.y - g), vec2(0.5664, 0.8241)));      // crown main, 34.5 degrees
    d = max(d, dot(vec2(x2 - R, p.y - g), vec2(0.6561, 0.7547)) + 0.012 * R);   // upper girdle, steeper
    d = max(d, dot(vec2(x1 - R * 0.62, p.y - g - 0.27 * R), vec2(0.2588, 0.9659)));   // star facets near the table
    d = max(d, dot(vec2(x1 - R, p.y + g), vec2(0.6528, -0.7576)));     // pavilion main, 40.75 degrees
    d = max(d, dot(vec2(x2 - R, p.y + g), vec2(0.6820, -0.7314)) + 0.01 * R);   // lower girdle
    return d;
}
float sdHeart2(vec2 p) {
    // a heart, tip at (0, 0), about 1 high (after Inigo Quilez, MIT)
    p.x = abs(p.x);
    if (p.y + p.x > 1.0)
        return length(p - vec2(0.25, 0.75)) - 0.35355339;
    vec2 a = p - vec2(0.0, 1.0), b = p - 0.5 * max(p.x + p.y, 0.0);
    return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}
float sdStar5(vec2 p, float r, float rf) {
    // a five-pointed star (after Inigo Quilez, MIT)
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
float sdRoundCone(vec3 p, float r1, float r2, float h) {
    // (after Inigo Quilez, MIT)
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    vec2 q = vec2(length(p.xz), p.y);
    float k = dot(q, vec2(-b, a));
    if (k < 0.0)
        return length(q) - r1;
    if (k > a * h)
        return length(q - vec2(0.0, h)) - r2;
    return dot(q, vec2(a, b)) - r1;
}
// A trefoil knot around the axis z: the tube winds twice around and three times through
float sdKnot(vec3 p, float R, float k, float th) {
    float r = length(p.xy);
    float a = atan(p.y, p.x);
    float d = 1e9;
    for (int i = 0; i < 2; i++) {
        float f = (a + 6.2831853 * float(i)) * 1.5;
        vec2 c = vec2(r - R, p.z) - k * vec2(cos(f), sin(f));
        d = min(d, length(c) - th);
    }
    return d;
}

// The shape k at p (object space)
float shapeDist(vec3 p, int k) {
    float s = gS;
    if (k == 0) {
        // the prism: an equilateral triangle (its faces 0.4 sizes from the middle), Depth x 0.8 sizes long
        return extrudeR(sdEqTri(p.xy, 0.6928203 * s), p.z, depth * 0.4 * s, 0.03 * s);
    } else if (k == 1) {
        float w = 1.1 * s;
        return sdPyramid((p + vec3(0.0, 0.42 * s, 0.0)) / w, 0.8) * w - 0.012 * s;
    } else if (k == 2) {
        vec3 q = mat3(0.8, 0.0, -0.6, 0.0, 1.0, 0.0, 0.6, 0.0, 0.8) * p;
        return sdRoundBox(q, vec3(0.52 * s), 0.05 * s);
    } else if (k == 3) {
        return sdGem(rotX(-0.55) * p, 0.66 * s);
    } else if (k == 4) {
        float d = 1e9;
        for (int i = 0; i < 5; i++) {
            vec3 q = (p - SH_C[i]) * SH_R[i];
            float e = max(max(dot(q.xy, SH_N[i].xy) - SH_D[i].x, dot(q.xy, SH_N[i].zw) - SH_D[i].y),
                          max(dot(q.xy, SH_M[i].xy) - SH_D[i].z, abs(q.z) - SH_D[i].w));
            d = min(d, e);
        }
        return d;
    } else if (k == 5) {
        return length(p) - 0.62 * s;
    } else if (k == 6) {
        vec2 q = vec2(length(p.xy) - 0.44 * s, p.z);
        return length(q) - 0.2 * s;
    } else if (k == 7) {
        vec3 q = p;
        q.y -= clamp(q.y, -0.36 * s, 0.36 * s);
        return length(q) - 0.3 * s;
    } else if (k == 8) {
        return sdOctahedron(p, 0.82 * s) - 0.015 * s;
    } else if (k == 9) {
        return sdDodeca(p, 0.52 * s);
    } else if (k == 10) {
        return sdIcosa(p, 0.55 * s);
    } else if (k == 11) {
        vec3 q = p;
        float an = q.y / s * 2.2;
        q.xz = mat2(cos(an), sin(an), -sin(an), cos(an)) * q.xz;
        return sdRoundBox(q, vec3(0.3 * s, 0.62 * s, 0.3 * s), 0.04 * s);
    } else if (k == 12) {
        return sdKnot(p, 0.4 * s, 0.17 * s, 0.11 * s);
    } else if (k == 13) {
        float d = length(p - BL[0].xyz) - BL[0].w;
        for (int i = 1; i < 5; i++)
            d = smin(d, length(p - BL[i].xyz) - BL[i].w, 0.22 * s);
        return d;
    } else if (k == 14) {
        float w = 1.25 * s;
        float d2 = sdHeart2(p.xy / w + vec2(0.0, 0.5)) * w;
        return extrudeR(d2, p.z, max(depth * 0.14, 0.12) * s, 0.11 * s);
    } else if (k == 15) {
        // a star with a ridge along each point, like a cut glass star
        float d2 = sdStar5(p.xy, 0.72 * s, 0.45);
        return max(d2, (abs(p.z) - max(depth * 0.03, 0.02) * s + 0.55 * min(d2, 0.0)) * 0.85);
    } else if (k == 16) {
        // a lens: two spheres overlapping
        return smax(length(p - vec3(0.0, 0.0, -0.8 * s)) - s, length(p + vec3(0.0, 0.0, -0.8 * s)) - s, 0.03 * s);
    }
    return sdRoundCone(p + vec3(0.0, 0.25 * s, 0.0), 0.4 * s, 0.04 * s, 0.72 * s);
}
// How far the shape k reaches from its middle, in sizes (any way it is turned)
float reachOf(int k) {
    if (k == 0)
        return sqrt(0.64 + 0.16 * depth * depth) + 0.03;
    if (k == 2 || k == 4)
        return 0.95;
    if (k == 8)
        return 0.84;
    if (k == 1 || k == 11 || k == 13)
        return 0.8;
    return 0.72;
}
float stepFor(int k) {
    if (k == 11)
        return 0.7;
    if (k == 12)
        return 0.6;
    if (k == 15 || k == 13)
        return 0.8;
    return 0.92;
}

// The object at p (object space): Twist, then Shape morphed into Morph shape
float objDist(vec3 p, int k) {
    if (gTwist != 0.0) {
        float an = p.y * gTwist;
        p.xz = mat2(cos(an), sin(an), -sin(an), cos(an)) * p.xz;
    }
    if (gMorph >= 0.999)
        return shapeDist(p, morph_shape);
    float d = shapeDist(p, k);
    if (gMorph > 0.001)
        d = mix(d, shapeDist(p, morph_shape), gMorph);
    return d;
}

// ---- the grid ----
// The copy of cell id: its middle, its turn and its shape
void cellSetup(ivec2 id, out vec3 c, out mat3 R, out int k) {
    c = vec3((vec2(id) - 0.5 * vec2(gN - 1)) * gCell, 0.0);
    vec3 h = hash33(vec3(vec2(id), 17.0));
    vec3 h2 = hash33(vec3(vec2(id), 29.0));
    float idx = float(id.x + id.y * gN.x);
    float a = gSpinA + radians(instance_rotation) * idx + instance_variation * ((h.x - 0.5) * 6.2831853 + (h.z - 0.5) * gTime * 0.4);
    float b = instance_variation * (h.y - 0.5) * 1.4;
    if (gN.x * gN.y == 1) {
        a = gSpinA;
        b = 0.0;
    }
    // world <- object
    R = rotY(gTumbleA + instance_variation * (h2.z - 0.5) * 1.2) * rotX(b) * rotZ(a);
    k = shape;
    if (h2.x < shape_variation && gN.x * gN.y > 1)
        k = int(h2.y * float(NSHAPES)) % NSHAPES;
}
void prepCell(ivec2 id) {
    if (id == cId)
        return;
    cId = id;
    cellSetup(id, cCenter, cRot, cShape);
    gStepK = min(stepFor(cShape), gMorph > 0.001 ? stepFor(morph_shape) : 1.0);
    if (gTwist != 0.0)
        gStepK *= 1.0 / (1.0 + abs(gTwist) * 0.6 * gS);
}
ivec2 cellOf(vec3 p) {
    return clamp(ivec2(floor(p.xy / gCell + 0.5 * vec2(gN))), ivec2(0), gN - 1);
}
// The distance to the copy of the current cell (prepCell first)
float localDist(vec3 p) {
    return objDist((p - cCenter) * cRot, cShape);
}
vec3 localNormal(vec3 p) {
    float e = 0.0008 * gS;
    const vec2 k = vec2(1.0, -1.0);
    return normalize(k.xyy * localDist(p + k.xyy * e) + k.yyx * localDist(p + k.yyx * e)
                   + k.yxy * localDist(p + k.yxy * e) + k.xxx * localDist(p + k.xxx * e));
}

// The objects for this frame: t the time in beats, wob the mids (degrees more rock), pumpLevel the spring of the music
void setupScene(float t, float wob, float pumpLevel) {
    gTime = t;
    gS = size * (1.0 + pump * clamp(pumpLevel, -0.5, 2.0));
    gSpinA = radians(turn + rock * sin(t * 6.2831853 / 8.0) + wob) + t * 6.2831853 / 16.0 * spin;
    // with the beam on, the prism keeps its axis towards the camera (the beam is aimed at its side, the album cover)
    gTumbleA = beam_intensity > 0.0 ? 0.0 : radians(tilt) + t * 6.2831853 / 16.0 * tumble;
    float m = morph;
    if (morph_cycle > 0.0)
        m = max(m, smoothstep(0.0, 1.0, 0.5 - 0.5 * cos(t * 6.2831853 / morph_cycle)));
    gMorph = clamp(m, 0.0, 1.0);
    if (morph_shape == shape)
        gMorph = 0.0;
    gTwist = twist * 6.2831853 / (1.3 * size);
    gN = ivec2(clamp(count_x, 1, 6), clamp(count_y, 1, 6));
    gCell = max(spacing, 0.5) * size * 1.2;
    if (gN.x * gN.y > 1) {
        // copies close together get smaller, so that none reaches into the cell of its neighbour (it would be cut)
        float reach = max(reachOf(shape), gMorph > 0.0 ? reachOf(morph_shape) : 0.0);
        if (shape_variation > 0.0)
            reach = 0.95;
        gS = min(size, 0.5 * gCell / (reach * (1.0 + 1.5 * pump))) * (1.0 + pump * clamp(pumpLevel, -0.5, 2.0));
    }
    float rb = size * (1.0 + 2.0 * pump) * max(1.15, sqrt(0.64 + 0.16 * depth * depth)) + 0.05;
    gHalf = vec3(0.5 * vec2(gN - 1) * gCell + rb, rb);
    floorY = -(0.5 * float(gN.y - 1) * gCell + 1.4 * size);
    cId = ivec2(-100);

    float s = gS;
    float a = gSpinA;
    for (int pc = 0; pc < 5; pc++) {
        // the shards: thin uneven triangles, each turned its own way
        vec3 h = hash33(vec3(float(pc), 3.0, 7.0));
        vec3 h2 = hash33(vec3(float(pc), 11.0, 5.0));
        float ang = float(pc) * 1.2566 + h.x * 0.8;
        SH_C[pc] = pc == 0 ? vec3(0.0) : vec3(cos(ang) * s * 0.62 * h.y, (h.z - 0.5) * s * 0.8, sin(ang) * s * 0.4 * h.y);
        float ax = h2.x * 6.2831853 + a * (0.5 + h2.y), ay = h2.y * 3.0 + a * 0.3, az = h2.z * 6.2831853;
        SH_R[pc] = rotZ(az) * rotY(ay) * rotX(ax);
        float r = s * (pc == 0 ? 0.4 : 0.17 + 0.13 * h.x);
        float a0 = h2.z * 0.6, a1 = 2.1 + h.x * 0.5, a2 = 4.2 + h.y * 0.4;
        SH_N[pc] = vec4(cos(a0), sin(a0), cos(a1), sin(a1));
        SH_M[pc] = vec4(cos(a2), sin(a2), 0.0, 0.0);
        SH_D[pc] = vec4(r, r * (0.8 + 0.4 * h2.x), r * (0.8 + 0.4 * h2.y), r * 0.1);
        // the blob: drops that circle around each other, the bass pushes them apart
        float ph = float(pc) * 1.9;
        float w = t * 6.2831853 / 8.0 * (0.6 + 0.25 * float(pc % 3));
        vec3 o = vec3(sin(w + ph), cos(w * 0.7 + ph * 1.3), sin(w * 0.5 + ph * 2.1) * 0.6);
        BL[pc] = vec4(o * s * (0.42 + 0.12 * clamp(pumpLevel, 0.0, 1.5)), s * (0.22 + 0.07 * h.x));
    }
}

// The nearest copy along a ray from outside: true and its distance tHit when it hits; prepCell holds its cell then.
// The step never goes past the edge of a cell the ray is in, so the copy of the next cell is looked at in time.
bool marchScene(vec3 ro, vec3 rd, float tmax, int steps, out float tHit) {
    tHit = -1.0;
    // the box around all copies
    vec3 inv = 1.0 / rd;
    vec3 t0 = (-gHalf - ro) * inv, t1 = (gHalf - ro) * inv;
    vec3 tn = min(t0, t1), tf = max(t0, t1);
    float ta = max(max(tn.x, tn.y), tn.z), tb = min(min(tf.x, tf.y), tf.z);
    if (ta > tb || tb < 0.0)
        return false;
    float t = max(ta, 0.0);
    float tEnd = min(tb, tmax);
    for (int i = 0; i < 160; i++) {
        if (i >= steps)
            break;
        vec3 p = ro + rd * t;
        ivec2 id = cellOf(p);
        prepCell(id);
        float d = localDist(p);
        float eps = 0.0005 * gS + 0.0002 * t;
        if (d < eps) {
            tHit = t;
            return true;
        }
        float st = d * gStepK;
        vec3 l = p - cCenter;
        if (gN.x > 1 && abs(rd.x) > 1e-5) {
            int nx = id.x + (rd.x > 0.0 ? 1 : -1);
            if (nx >= 0 && nx < gN.x)
                st = min(st, ((rd.x > 0.0 ? 0.5 : -0.5) * gCell - l.x) / rd.x + 0.002 * gS);
        }
        if (gN.y > 1 && abs(rd.y) > 1e-5) {
            int ny = id.y + (rd.y > 0.0 ? 1 : -1);
            if (ny >= 0 && ny < gN.y)
                st = min(st, ((rd.y > 0.0 ? 0.5 : -0.5) * gCell - l.y) / rd.y + 0.002 * gS);
        }
        t += max(st, 0.0004 * gS);
        if (t > tEnd)
            return false;
    }
    return false;
}
// A ray inside the copy of the current cell: the distance to the wall it leaves through, or -1 when the march did
// not get there (a ray that grazes a wall from inside takes tiny steps; its normal would be noise: sparse dots)
float marchInside(vec3 p, vec3 d, int steps) {
    float t = 0.0;
    for (int i = 0; i < 96; i++) {
        if (i >= steps)
            return -1.0;
        float dd = -localDist(p + d * t);
        if (dd < 0.0005 * gS)
            return t;
        t += max(dd * gStepK, 0.0025 * gS);
    }
    return -1.0;
}

// The index of refraction at a wavelength (nm), Sellmeier, spread by Dispersion around its value at 589 nm
float sellmeierOf(int g, float lnm) {
    float l2 = lnm * lnm * 1e-6;
    vec3 B, C;
    if (g == 0) {
        B = vec3(1.03961212, 0.231792344, 1.01046945);
        C = vec3(0.00600069867, 0.0200179144, 103.560653);
    } else if (g == 1 || g == 4) {
        B = vec3(1.73759695, 0.313747346, 1.89878101);
        C = vec3(0.013188707, 0.0623068142, 155.23629);
    } else if (g == 2) {
        B = vec3(0.6961663, 0.4079426, 0.8974794);
        C = vec3(0.00467914826, 0.0135120631, 97.9340025);
    } else {
        B = vec3(4.3356, 0.3306, 0.0);
        C = vec3(0.011236, 0.030625, 1.0);
    }
    vec3 term = B * l2 / (l2 - C);
    return sqrt(1.0 + term.x + term.y + term.z);
}
float sellmeier(float lnm) {
    if (glass == 4)
        return ior + sellmeierOf(4, lnm) - sellmeierOf(4, 589.0);
    return sellmeierOf(glass, lnm);
}
float iorAt(float lnm, float extra) {
    float n0 = sellmeier(589.0);
    return max(n0 + (sellmeier(lnm) - n0) * dispersion * extra, 1.0001);
}

// The colour of a wavelength (nm) in linear sRGB, unnormalized (a sum of Gaussian lobes near the CIE curves)
vec3 spectralRGB(float lnm) {
    float r = exp(-pow((lnm - 610.0) / 45.0, 2.0)) + 0.35 * exp(-pow((lnm - 430.0) / 22.0, 2.0));
    float g = exp(-pow((lnm - 545.0) / 42.0, 2.0));
    float b = exp(-pow((lnm - 455.0) / 32.0, 2.0));
    vec3 c = vec3(r, g, b);
    // a little purer: take some of the other channels away
    c = max(c - 0.15 * (c.r + c.g + c.b - c) * 0.5, 0.0);
    return c;
}
float fanWavelength(int j) {
    return 400.0 + (float(j) + 0.5) / float(FAN) * 300.0;
}
// The white of the fan: the sum of all its colours, so the colours add up to white
vec3 fanWhite() {
    vec3 s = vec3(0.0);
    for (int j = 0; j < FAN; j++)
        s += spectralRGB(fanWavelength(j));
    return s;
}

// Where the beam starts and where it goes. Prism: it hits the middle of the left face at the angle of minimum
// deviation of the glass (the path of the album cover) plus Beam angle; the other shapes: Beam angle is its rise.
// It aims at the copy nearest the middle.
void beamStart(out vec3 o, out vec3 d) {
    float el = radians(beam_angle), az = radians(beam_direction);
    vec3 c0 = vec3((vec2(cellOf(vec3(0.0))) - 0.5 * vec2(gN - 1)) * gCell, 0.0);
    vec3 aim = c0 + vec3(0.0, beam_offset * size, 0.0);
    if (shape == 0) {
        mat3 rr = rotZ(radians(turn));
        vec3 nl = rr * vec3(-0.866025, 0.5, 0.0);
        vec3 tl = rr * vec3(0.5, 0.866025, 0.0);
        aim = c0 + nl * size * 0.4 + tl * beam_offset * size;
        float iMin = asin(clamp(sellmeier(589.0) * 0.5, 0.0, 1.0));
        float ang = atan(-nl.y, -nl.x) + iMin + el;
        d = vec3(cos(ang), sin(ang), 0.0);
    } else {
        d = vec3(cos(el), sin(el), 0.0);
    }
    d = normalize(vec3(d.x * cos(az), d.y, d.x * sin(az)));
    o = aim - d * 30.0;
}

// The glow of a beam (a segment a + v t, t in 0 .. len) seen along a ray o + u s, s in 0 .. smax: the light it
// scatters towards the eye from the haze, widening by `grow` per unit
float segmentGlow(vec3 o, vec3 u, float smax, vec3 a, vec3 v, float len, float w0, float grow) {
    vec3 w = o - a;
    float b = dot(u, v), dd = dot(u, w), e = dot(v, w);
    float den = max(1.0 - b * b, 1e-4);
    float s = clamp((b * e - dd) / den, 0.0, smax);
    float t = clamp(dot(o + u * s - a, v), 0.0, len);
    s = clamp(dot(a + v * t - o, u), 0.0, smax);
    vec3 q = (o + u * s) - (a + v * t);
    float width = w0 + grow * t;
    float d2 = dot(q, q) / (width * width);
    // seen along the beam it looks brighter (more of it in the line of sight), but not endlessly
    float along = 1.0 / max(sqrt(den), 0.12);
    return exp(-d2) * along * (w0 / width);
}

// ---- Shared by all passes: the sound, the glitch, the picture controls ----

// The sound: the texture of the audio analysis (AudioInputAnalysis), 512 x 2, row 0 the spectrum (512 bands, log
// spaced from 20 Hz, 0 .. 1), row 1 the waveform. Link the analysis into the port Audio; a VibeVJ that binds AUDIO by
// itself does it while an analysis runs. Without sound the object follows the beat of the timeline (Music Auto).
uniform sampler2D AUDIO;
uniform int AUDIO_ON;               // set by the engine: 1 while AUDIO has a picture (no control)

//@enum options=(Auto, Sound, Beat, Off) value=0
uniform int music;                  // Auto: the sound while it plays, else the beat. Sound: only the sound. Beat: only the beat
//@slider min=0.0 max=4.0 value=1.0
uniform float music_gain;           // multiplies the levels of the sound
//@slider min=0.0 max=2.0 value=1.0
uniform float react;                // how strongly the music moves the object

//@slider min=0.0 max=1.0 value=0.0
uniform float glitch;               // glitch all the time
//@enum options=(Mix, Slices, RGB split, Tear, Shatter) value=0
uniform int glitch_kind;            // Shatter breaks the object into blocks; Mix changes between all of them
//@slider min=0.0 max=1.0 value=0.0
uniform float glitch_on_beat;       // a glitch on every Glitch every-th beat
//@int min=1 max=16 value=4
uniform int glitch_every;           // beats between the glitches of Glitch on beat
//@slider min=0.0 max=1.0 value=0.0
uniform float glitch_on_sound;      // a glitch on the kicks of the sound
//@slider min=0.05 max=4.0 value=0.5
uniform float glitch_length;        // seconds a glitch of Glitch on beat / Glitch on sound fades in
//@button
uniform bool glitch_hold;           // full glitch while on: map it to a MIDI pad or key

//@enum options=(Scene, Colour, Transparent) value=0
uniform int background_mode;        // Transparent: black and alpha 0 around the object, for Add or an Over with alpha
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background_color;      // Background mode Colour
//@int min=1 max=3 value=2
uniform int quality;                // 1 live and cheap, 2 the full look, 3 with 4x antialiasing (4 times the cost)

// The spring of pass S: an asset can define its own before this file
#ifndef SPRING_STIFF
#define SPRING_STIFF 90.0
#endif
#ifndef SPRING_DAMP
#define SPRING_DAMP 9.0
#endif

const float LIB_TAU = 6.28318530718;

// A value of the last frame, or `fallback` when it is no number (a fresh texture can hold anything)
vec4 stateOr(vec4 v, vec4 fallback) {
    return (any(isnan(v)) || any(isinf(v))) ? fallback : v;
}

// A texture of a pass at uv, bilinear (the textures of passes are nearest)
vec4 passBilinear(sampler2D s, vec2 uv) {
    ivec2 sz = textureSize(s, 0);
    vec2 p = uv * vec2(sz) - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    ivec2 a = ivec2(i);
    ivec2 mx = sz - 1;
    vec4 c00 = texelFetch(s, clamp(a, ivec2(0), mx), 0);
    vec4 c10 = texelFetch(s, clamp(a + ivec2(1, 0), ivec2(0), mx), 0);
    vec4 c01 = texelFetch(s, clamp(a + ivec2(0, 1), ivec2(0), mx), 0);
    vec4 c11 = texelFetch(s, clamp(a + ivec2(1, 1), ivec2(0), mx), 0);
    return mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
}

// ---- The sound ----
// Where a frequency (Hz) lies on the spectrum row, 0 .. 1 (log spaced from 20 Hz to 24 kHz)
float freqToX(float hz) {
    return clamp(log(max(hz, 20.0) / 20.0) / log(1200.0), 0.0, 1.0);
}
float audioBand(int i) {
    return clamp(texelFetch(AUDIO, ivec2(clamp(i, 0, 511), 0), 0).r, 0.0, 1.0);
}
// The mean of the bands between two frequencies, at most 32 bands looked at
float bandMean(float hzA, float hzB) {
    int a = int(freqToX(hzA) * 511.0), b = int(freqToX(hzB) * 511.0);
    int stp = max(1, (b - a) / 32);
    float v = 0.0, n = 0.0;
    for (int k = a; k <= b; k += stp) {
        v += audioBand(k);
        n += 1.0;
    }
    return v / max(n, 1.0);
}
// The levels the beat makes up when there is no sound: a kick on every beat, a snare on 2 and 4, hats between
vec4 beatLevels(float t) {
    float kick = exp(-fract(t) * 6.0);
    float snare = exp(-fract(t * 0.5 + 0.5) * 7.0);
    float hat = exp(-fract(t + 0.5) * 12.0);
    return vec4(0.85 * kick, 0.6 * snare + 0.15, 0.5 * hat + 0.1, 0.5 * kick + 0.3);
}

// ---- The state pass S, one pixel each ----
// 0: levels (bass, mid, high, loudness), 0 .. ~1, what moves the object (already Beat when there is no sound)
// 1: (beat envelope, glitch envelope, glitch seed, the iTime of the last frame)
// 2: (slow bass, kick envelope, seconds since the sound was last heard, 1 while the sound counts)
// 3: (spring position, spring velocity, -, -): the music through a damped spring
const int ST_LEVELS = 0;
const int ST_BEAT = 1;
const int ST_SOUND = 2;
const int ST_SPRING = 3;

// The glitch amount now, 0 .. 1, from the controls and the envelope of the state
float glitchAmount(vec4 beatState) {
    return clamp(glitch + beatState.y + (glitch_hold ? 1.0 : 0.0), 0.0, 1.0);
}
// The kind of glitch for this seed: Mix picks one of the four per glitch
int glitchKindFor(float seed) {
    if (glitch_kind != 0)
        return glitch_kind;
    return 1 + int(floor(fract(seed * 7.31) * 4.0));
}
