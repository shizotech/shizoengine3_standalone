//@settings dtype=float32 format=rgba

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
// Random vec2 in [0,1)^2 for an integer-valued 2D input.
vec2 hash22(vec2 p) {
    ivec2 q = ivec2(floor(p));
    return uintToUnit(pcg3d(uvec3(q.x, q.y, 0x2545u))).xy;
}

// ---- shader-skills library: sdf3d ----
// Sphere of radius r.
float sdSphere(vec3 p, float r) { return length(p) - r; }
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
// Torus in the XZ plane. t.x = major radius, t.y = tube radius.
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}
// Chain link: a torus stretched along Y by le. r1 = major radius, r2 = tube radius.
float sdLink(vec3 p, float le, float r1, float r2) {
    vec3 q = vec3(p.x, max(abs(p.y) - le, 0.0), p.z);
    return length(vec2(length(q.xy) - r1, q.z)) - r2;
}
// Hexagonal prism along Z. h.x = inradius of the hexagon, h.y = half-length.
float sdHexPrism(vec3 p, vec2 h) {
    const vec3 k = vec3(-0.8660254, 0.5, 0.57735027);
    p = abs(p);
    p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
    vec2 d = vec2(length(p.xy - vec2(clamp(p.x, -k.z * h.x, k.z * h.x), h.x)) * sign(p.y - h.x),
                  p.z - h.y);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}
// Regular octahedron with "radius" s (vertex distance from center). Bound version.
float sdOctahedron(vec3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}
// Gyroid sheet with cell scale `scale` and half-thickness t. The infinite triply-periodic surface sin x cos y + sin y cos z + sin z cos x = 0. Intersect with a bounding shape.
float sdGyroid(vec3 p, float scale, float t) {
    p *= scale;
    float g = dot(sin(p), cos(p.yzx));
    return (abs(g) / scale - t) * 0.57735027;
}

// ---- shader-skills library: sdf2d ----
// Axis-aligned rectangle with half-extents b.
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// ---- shader-skills library: operators ----
// Smooth union that also returns the blend weight. Returns vec2(distance, weight), where weight is 1 when the result is fully a and 0 when fully b. Use the weight to mix material colors across the blend.
vec2 sminBlend(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return vec2(mix(b, a, h) - k * h * (1.0 - h), h);
}

// ---- shader-skills library: domain ----
// Repetition limited to cells -lim..+lim on each axis (2*lim + 1 copies).
vec2 domRepeatLimited(vec2 p, vec2 s, vec2 lim) { return p - s * clamp(floor(p / s + 0.5), -lim, lim); }
vec3 domRepeatLimited(vec3 p, vec3 s, vec3 lim) { return p - s * clamp(floor(p / s + 0.5), -lim, lim); }
// Polar repetition into n sectors around the origin. Returns the point rotated into the sector centered on +X. Single evaluation: exact for shapes symmetric about their sector's center line. For asymmetric or per-sector-varying shapes, evaluate this sector and its neighbor and take the min (see references/sdf-library-guide.md).
vec2 domPolar(vec2 p, float n) {
    if (dot(p, p) < 1e-20) return p;
    float sector = TAU / n;
    float id = floor(atan(p.y, p.x) / sector + 0.5);
    return rot2(-id * sector) * p;
}
// Twist around Y: rotate XZ by k * y. Divide the resulting distance by L = a/2 + sqrt(1 + a*a/4), a = k * R, where R is the shape's max distance from the Y axis. Without that, the march overshoots.
vec3 domTwist(vec3 p, float k) {
    vec2 xz = rot2(k * p.y) * p.xz;
    return vec3(xz.x, p.y, xz.y);
}

// ---- shader-skills library: raymarch ----
#define ZERO (min(iFrame, 0))
vec2 map(vec3 p);
// Surface normal from 4 tetrahedral samples (cheaper than 6 central differences, and still centered). eps should scale with distance, e.g. 0.0005 * t: that filters distant detail and avoids sparkling.
vec3 calcNormal(vec3 p, float eps) {
    vec3 n = vec3(0.0);
    for (int i = ZERO; i < 4; i++) {
        vec3 e = 0.5773 * (2.0 * vec3((((i + 3) >> 1) & 1), ((i >> 1) & 1), (i & 1)) - 1.0);
        n += e * map(p + e * eps).x;
    }
    return normalize(n);
}
// Soft shadow toward a light along unit rd. k controls sharpness (k is about 1 / light angular size: 8 soft, 32 hard). Uses the "closest approach between samples" estimate, which removes banding from sharp-cornered occluders. Returns 0 (full shadow) .. 1 (lit).
float softShadow(vec3 ro, vec3 rd, float tmin, float tmax, float k) {
    float res = 1.0;
    float t = tmin;
    float ph = 1e10;
    for (int i = ZERO; i < 64; i++) {
        float h = map(ro + rd * t).x;
        if (h < 0.0001) return 0.0;
        float y = h * h / (2.0 * ph);
        float d = sqrt(max(h * h - y * y, 0.0));
        res = min(res, k * d / max(t - y, 1e-4));
        ph = h;
        t += clamp(h, 0.005, 0.5);
        if (res < 0.001 || t > tmax) break;
    }
    res = clamp(res, 0.0, 1.0);
    return res * res * (3.0 - 2.0 * res);
}
// Ambient occlusion from 5 distance samples along the normal. Compares the expected distance with the actual one. scale is the sampling reach in scene units (about 0.12 for a unit-sized object). Returns 0 (occluded) .. 1 (open).
float calcAO(vec3 p, vec3 n, float scale) {
    float occ = 0.0;
    float weight = 1.0;
    for (int i = ZERO; i < 5; i++) {
        float h = 0.01 + scale * float(i) / 4.0;
        float d = map(p + h * n).x;
        occ += (h - d) * weight;
        weight *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ / max(scale / 0.12, 1e-3), 0.0, 1.0);
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
// Complete metallic-roughness shading for one light (diffuse + specular, NoL included, artist units). Multiply by light color and shadow. Keep albedo around 0.05-0.7 (linear); brighten lights, not albedo.
vec3 shadePBR(vec3 n, vec3 v, vec3 l, vec3 albedo, float roughness, float metallic) {
    vec3 f0 = mix(vec3(0.04), albedo, metallic);
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    vec3 F = fresnelSchlick(max(dot(n, v), 0.0), f0);
    vec3 diffuse = albedo * (1.0 - metallic) * (1.0 - F) * NoL;
    return diffuse + specularGGX(n, v, l, roughness, f0);
}
// Hemisphere light: sky color from above blended to ground color from below.
vec3 hemisphereLight(vec3 n, vec3 skyColor, vec3 groundColor) {
    return mix(groundColor, skyColor, 0.5 + 0.5 * n.y);
}
// Rim light from the viewing angle: strongest at silhouettes.
float rimLight(vec3 n, vec3 v, float power) {
    return pow(clamp(1.0 - dot(n, v), 0.0, 1.0), power);
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

// ---- shader-skills library: post ----
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

// ---- shader ----
// --- SDFScene: a raymarched 3D object with every part on a control (a small Render TOP / SOP scene) ---
// Shape A and Shape B are mixed by Morph. Satellites are small balls on orbits that melt into the object (Blend).
// Twist turns the object along its height, Copies repeats it as a grid or a ring. The camera orbits the middle.
// Light: one key light (Light angle) with PBR shading, a sky / ground fill, a rim light and fog into the background.
// iTime counts beats in Sync: Spin is in turns per 8 beats, Beat pulse swells the object at every beat.
// Cost: Quality 1 marches up to 64 steps per pixel with no shadow, 2 up to 110 with a soft shadow, 3 up to 160 with
// 4x antialiasing. Copies and Satellites add to every step.

//@enum options=(Sphere, Box, Torus, Octahedron, Gyroid ball, Link, Hex prism, Cross) value=1
uniform int shape_a;
//@enum options=(Sphere, Box, Torus, Octahedron, Gyroid ball, Link, Hex prism, Cross) value=2
uniform int shape_b;
//@slider min=0.0 max=1.0 value=0.0
uniform float morph;                // 0 = Shape A, 1 = Shape B
//@slider min=0.3 max=1.5 value=0.8
uniform float size;
//@slider min=0.0 max=0.4 value=0.08
uniform float roundness;
//@slider min=-3.0 max=3.0 value=0.0
uniform float twist;                // turns of the object along its height
//@int min=0 max=8 value=4
uniform int satellites;
//@slider min=0.0 max=1.0 value=0.4
uniform float blend;                // how much the satellites melt into the object
//@enum options=(Single, Grid, Ring) value=0
uniform int copies;
//@slider min=1.5 max=5.0 value=2.6
uniform float spacing;              // distance between the copies
//@slider min=-2.0 max=2.0 value=0.5
uniform float spin;                 // turns per 8 beats
//@slider min=0.0 max=1.0 value=0.3
uniform float beat_pulse;
//@slider min=2.0 max=12.0 value=4.0
uniform float camera_distance;
//@slider min=-1.0 max=1.0 value=0.3
uniform float camera_height;
//@slider min=-1.0 max=1.0 value=0.1
uniform float camera_orbit;         // turns of the camera per 16 beats
//@rgb value=(0.9, 0.35, 0.15)
uniform vec3 color_a;               // the object
//@rgb value=(0.15, 0.6, 1.0)
uniform vec3 color_b;               // the satellites
//@rgb value=(1.0, 0.95, 0.85)
uniform vec3 light_color;
//@slider min=0.0 max=360.0 value=40.0
uniform float light_angle;          // degrees around the object
//@slider min=0.0 max=3.0 value=1.0
uniform float rim;
//@slider min=0.05 max=1.0 value=0.35
uniform float roughness;
//@slider min=0.0 max=1.0 value=0.0
uniform float metallic;
//@rgb value=(0.02, 0.02, 0.06)
uniform vec3 background;
//@slider min=0.0 max=0.3 value=0.04
uniform float fog;
//@int min=1 max=3 value=1
uniform int quality;
//@enum options=(Final, Normals, Steps, Depth) value=0
uniform int debug_mode;

float shapeDist(vec3 p, int s, float r) {
    if (s == 0) return sdSphere(p, r);
    if (s == 1) return sdRoundBox(p, vec3(r * 0.75), roundness * r);
    if (s == 2) return sdTorus(p, vec2(r * 0.8, r * 0.28 + roundness * 0.3));
    if (s == 3) return sdOctahedron(p, r * 1.25) - roundness * r * 0.5;
    if (s == 4) return max(sdSphere(p, r), sdGyroid(p, 5.0 / r, 0.03 + roundness * 0.1));
    if (s == 5) return sdLink(p, r * 0.35, r * 0.45, r * 0.15 + roundness * 0.2);
    if (s == 6) return sdHexPrism(p.xzy, vec2(r * 0.8, r * 0.6)) - roundness * r * 0.5;
    float c = r * (0.22 + roundness * 0.4);
    return min(sdBox(p, vec3(r, c, c)), min(sdBox(p, vec3(c, r, c)), sdBox(p, vec3(c, c, r)))) - roundness * r * 0.3;
}

vec2 map(vec3 p) {
    float t = iTime;
    // Copies: a 3 x 1 x 3 grid or a ring of 6 around the middle
    vec3 q = p;
    if (copies == 1)
        q = domRepeatLimited(p, vec3(spacing), vec3(1.0, 0.0, 1.0));
    else if (copies == 2) {
        vec2 s = domPolar(p.xz, 6.0);
        q = vec3(s.x - spacing, p.y, s.y);
    }

    float r = size * (1.0 + beat_pulse * 0.25 * pow(1.0 - fract(t), 3.0));
    vec3 o = q;
    o.xz = rot2(t * spin * TAU / 8.0) * o.xz;
    o.xy = rot2(t * spin * TAU / 13.0) * o.xy;
    if (twist != 0.0)
        o = domTwist(o, twist * TAU / (2.0 * r + 1e-3) * 0.5);

    float d = mix(shapeDist(o, shape_a, r), shapeDist(o, shape_b, r), morph);
    float mat = 1.0;

    int n = clamp(satellites, 0, 8);
    float k = blend * 0.5 + 1e-3;
    for (int i = 0; i < 8; i++) {
        if (i >= n)
            break;
        float fi = float(i);
        float a = t * (0.25 + 0.07 * fi) * TAU / 4.0 + fi * 2.399;
        vec3 c = vec3(cos(a), sin(a * 0.7 + fi) * 0.6, sin(a)) * r * (1.25 + 0.15 * sin(fi * 1.7));
        float ds = sdSphere(q - c, r * 0.22);
        vec2 sb = sminBlend(d, ds, k);
        mat = mix(2.0, mat, sb.y);
        d = sb.x;
    }
    return vec2(d, mat);
}

// Sphere tracing with a step limit from Quality. Returns (t, material, steps); t < 0 on a miss
vec3 march(vec3 ro, vec3 rd, int maxSteps, float stepScale) {
    float t = 0.05;
    for (int i = 0; i < 160; i++) {
        if (i >= maxSteps)
            break;
        vec2 h = map(ro + rd * t);
        if (abs(h.x) < 0.0005 * t)
            return vec3(t, h.y, float(i));
        t += h.x * stepScale;
        if (t > 40.0)
            break;
    }
    return vec3(-1.0, 0.0, float(maxSteps));
}

vec3 render(vec2 uv) {
    float orbit = iTime * camera_orbit * TAU / 16.0 + 0.6;
    vec3 ro = camera_distance * vec3(cos(orbit) * cos(camera_height), sin(camera_height), sin(orbit) * cos(camera_height));
    mat3 cam = cameraMatrix(ro, vec3(0.0), 0.0);
    vec3 rd = cameraRay(cam, uv, 2.0);

    int steps = quality <= 1 ? 64 : (quality == 2 ? 110 : 160);
    float stepScale = twist != 0.0 ? 0.6 : 0.9;
    vec3 hit = march(ro, rd, steps, stepScale);

    vec3 bg = srgbToLinear(background) * (1.0 + 0.6 * (1.0 - abs(uv.y)));
    if (debug_mode == 2)
        return debugHeat(hit.z / float(steps));
    if (hit.x < 0.0)
        return debug_mode == 0 ? bg : vec3(0.0);

    vec3 pos = ro + rd * hit.x;
    vec3 n = calcNormal(pos, 0.0005 * hit.x);
    if (debug_mode == 1)
        return debugNormal(n);
    if (debug_mode == 3)
        return vec3(exp(-0.15 * hit.x));

    vec3 albedo = srgbToLinear(mix(color_a, color_b, clamp(hit.y - 1.0, 0.0, 1.0))) * 0.8;
    vec3 v = -rd;
    float la = radians(light_angle);
    vec3 l = normalize(vec3(cos(la), 0.9, sin(la)));
    float shadow = quality >= 2 ? softShadow(pos + n * 0.01, l, 0.02, 8.0, 12.0) : 1.0;
    float ao = calcAO(pos, n, 0.25);
    vec3 lc = srgbToLinear(light_color);

    vec3 col = shadePBR(n, v, l, albedo, roughness, metallic) * lc * 3.0 * shadow;
    col += albedo * hemisphereLight(n, vec3(0.35, 0.4, 0.55), vec3(0.08, 0.06, 0.05)) * ao;
    col += mix(albedo, lc, 0.5) * rimLight(n, v, 3.0) * rim * ao;
    col = mix(col, bg, 1.0 - exp(-fog * fog * hit.x * hit.x));
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int aa = quality >= 3 ? 2 : 1;
    vec3 col = vec3(0.0);
    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            if (i >= aa || j >= aa)
                continue;
            vec2 o = aa > 1 ? (vec2(float(i), float(j)) + 0.5) / float(aa) - 0.5 : vec2(0.0);
            vec2 uv = (2.0 * (fragCoord + o) - iResolution.xy) / iResolution.y;
            vec3 c = render(uv);
            col += debug_mode == 0 ? tonemapAgX(c) : c;
        }
    }
    col /= float(aa * aa);
    if (debug_mode == 0)
        col = linearToSrgb(col) + ditherTPDF(fragCoord, iFrame);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
