// --- Monolith: the code every pass includes ---
// ---- Monolith ----
#define SPRING_STIFF 70.0
#define SPRING_DAMP 7.0

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float PI  = 3.14159265358979;
const float TAU = 6.28318530717959;
// 2D rotation matrix. `rot2(a) * v` rotates v counter-clockwise by a radians. (cos, sin) is renormalized because GLSL ES leaves trig precision undefined: on SwiftShader and some mobile GPUs a raw cos/sin pair is far enough from unit length that rotations stop preserving distances.
mat2 rot2(float a) {
    vec2 cs = normalize(vec2(cos(a), sin(a)));
    return mat2(cs.x, cs.y, -cs.y, cs.x);
}

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
// Random float in [0,1) for an integer-valued input.
float hash11(float p) { return uintToUnit(pcgHash(uint(int(floor(p))))); }
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
const int FBM_MAX_OCTAVES = 12;
// Fractional Brownian motion over 2D gradient noise. Each octave is rotated to hide lattice alignment. persistence 0.5 is the classic look (H = 1). Lower is smoother, higher is rougher.
float fbm(vec2 p, int octaves, float lacunarity, float persistence) {
    const mat2 octaveRotation = mat2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        sum += amp * gradientNoise(p);
        norm += amp;
        amp *= persistence;
        p = lacunarity * (octaveRotation * p) + vec2(17.13, -3.71);
    }
    return 1.4 * sum / norm;
}
// 2D fBm with the usual defaults (lacunarity 2.01 so octave peaks never re-align, persistence 0.5).
float fbm(vec2 p, int octaves) { return fbm(p, octaves, 2.01, 0.5); }
// fBm over 3D gradient noise.
float fbm(vec3 p, int octaves, float lacunarity, float persistence) {
    const mat3 octaveRotation = mat3(0.00, 0.80, 0.60,
                                     -0.80, 0.36, -0.48,
                                     -0.60, -0.48, 0.64);
    float sum = 0.0, amp = 1.0, norm = 0.0;
    for (int i = 0; i < FBM_MAX_OCTAVES; i++) {
        if (i >= octaves) break;
        sum += amp * gradientNoise(p);
        norm += amp;
        amp *= persistence;
        p = lacunarity * (octaveRotation * p) + vec3(17.13, -3.71, 5.29);
    }
    return sum / norm;
}

// ---- shader-skills library: sdf3d ----
// Axis-aligned box with half-extents b.
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}
// Box with rounded edges. The outer size stays b; r is the edge radius (r <= min(b)).
float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}
// Regular octahedron with "radius" s (vertex distance from center). Bound version.
float sdOctahedron(vec3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

// ---- shader-skills library: sdf2d ----
// Axis-aligned rectangle with half-extents b.
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// ---- shader-skills library: domain ----
// Polar repetition into n sectors around the origin. Returns the point rotated into the sector centered on +X. Single evaluation: exact for shapes symmetric about their sector's center line. For asymmetric or per-sector-varying shapes, evaluate this sector and its neighbor and take the min (see references/sdf-library-guide.md).
vec2 domPolar(vec2 p, float n) {
    if (dot(p, p) < 1e-20) return p;
    float sector = TAU / n;
    float id = floor(atan(p.y, p.x) / sector + 0.5);
    return rot2(-id * sector) * p;
}

// ---- shader-skills library: intersect ----
// Ray vs sphere centered at c with radius r. Returns vec2(tNear, tFar), or vec2(-1) on a miss. Uses the precision-friendly form that measures from the closest point on the ray.
vec2 iSphere(vec3 ro, vec3 rd, vec3 c, float r) {
    vec3 oc = ro - c;
    float b = dot(oc, rd);
    vec3 qc = oc - b * rd;
    float h = r * r - dot(qc, qc);
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

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
// GGX / Trowbridge-Reitz normal distribution. alpha = roughness^2.
float distributionGGX(float NoH, float alpha) {
    float a2 = alpha * alpha;
    float d = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (PI * d * d);
}
// Height-correlated Smith visibility. Already contains the 1 / (4 NoL NoV) term.
float visibilitySmithGGX(float NoV, float NoL, float alpha) {
    float a2 = alpha * alpha;
    float gv = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float gl = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / max(gv + gl, 1e-6);
}
// Microfacet specular for one light: pi * D * V * F * NoL (artist units). roughness is perceptual, in [0,1].
vec3 specularGGX(vec3 n, vec3 v, vec3 l, float roughness, vec3 f0) {
    vec3 h = normalize(v + l);
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoV = max(dot(n, v), 1e-4);
    float NoH = clamp(dot(n, h), 0.0, 1.0);
    float VoH = clamp(dot(v, h), 0.0, 1.0);
    float alpha = max(roughness, 0.045);
    alpha *= alpha;
    return PI * distributionGGX(NoH, alpha) * visibilitySmithGGX(NoV, NoL, alpha) * fresnelSchlick(VoH, f0) * NoL;
}
// Split-sum environment specular without a lookup texture (Karis 2014, after Lazarov). Multiply by the sky or environment color in the reflection direction.
vec3 envBRDFApprox(vec3 f0, float NoV, float roughness) {
    vec4 r = roughness * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
    float a = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    vec2 ab = vec2(-1.04, 1.04) * a + r.zw;
    return f0 * ab.x + ab.y;
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

// ---- Monolith ----
#define SPRING_STIFF 70.0
#define SPRING_DAMP 7.0

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


// ---- Monolith: the camera and the glow, shared by pass A (the object) and pass R (the light rays) ----
//@slider min=0.3 max=2.0 value=1.0
uniform float size;
//@slider min=0.0 max=1.0 value=0.15
uniform float hover;                // floats up and down over 8 beats
//@slider min=2.0 max=14.0 value=7.5
uniform float camera_distance;
//@slider min=-20.0 max=80.0 value=10.0
uniform float camera_height;        // degrees above the floor
//@slider min=0.0 max=360.0 value=25.0
uniform float camera_angle;         // degrees around the object
//@slider min=-1.0 max=1.0 value=0.06
uniform float camera_orbit;         // turns per 16 beats
//@slider min=0.8 max=5.0 value=2.2
uniform float zoom;
//@slider min=0.0 max=1.0 value=0.2
uniform float camera_shake;         // a slow hand-held drift

//@slider min=-1.0 max=1.0 value=0.0
uniform float color_cycle;          // turns of the hue of the lines, the glow and the rays per 16 beats (0: fixed)
//@slider min=0.0 max=3.0 value=1.2
uniform float rays;                 // light rays that shoot out of the glow into the space around
//@slider min=0.0 max=1.0 value=0.6
uniform float ray_length;
//@int min=2 max=48 value=12
uniform int ray_count;              // how many bright beams stand out between the rays
//@slider min=-1.0 max=1.0 value=0.1
uniform float ray_spin;             // turns of the beams per 16 beats

// The height of the hover at the time t (beats)
float bobAt(float t) {
    return hover * 0.25 * size * sin(t * LIB_TAU / 8.0);
}

// The camera at the time t: where it is (ro) and how it looks (cam, columns right, up, forward)
void cameraSetup(float t, out vec3 ro, out mat3 cam) {
    float bob = bobAt(t);
    float ca = radians(camera_angle) + t * LIB_TAU / 16.0 * camera_orbit;
    float ch = radians(camera_height);
    float shake = camera_shake * 0.04;
    ca += shake * gradientNoise(vec2(t * 0.11, 1.7)) * 2.0;
    ch += shake * gradientNoise(vec2(t * 0.13, 5.3));
    ro = camera_distance * size * vec3(cos(ch) * cos(ca), sin(ch), cos(ch) * sin(ca));
    vec3 ta = vec3(0.0, bob * 0.5 - size * 0.05, 0.0);
    cam = cameraMatrix(ro, ta, shake * gradientNoise(vec2(t * 0.09, 3.1)) * 0.5);
}

// Where the middle of the object is in the picture (0 .. 1), for the rays
vec2 objectOnScreen(float t, vec2 res) {
    vec3 ro;
    mat3 cam;
    cameraSetup(t, ro, cam);
    vec3 d = vec3(0.0, bobAt(t), 0.0) - ro;
    vec3 c = d * cam;
    vec2 uv = c.xy / max(c.z, 1e-3) * zoom;
    return (uv * res.y + res) * 0.5 / res;
}

// A colour turned around the grey axis by a radians (the hue), in linear light
vec3 hueRotate(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a);
    return max(c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca), vec3(0.0));
}
float hueAngleAt(float t) {
    return t * LIB_TAU / 16.0 * color_cycle;
}
