//@settings dtype=float32 format=rgba
// --- Stage: objects on a shiny floor under a light that follows the beat (a small 3D scene: Render TOP with a
// Geometry COMP, a floor and a spot light) ---
// The objects are raymarched (one shape, copied into a row, a ring or a grid); the floor is a plane that is hit
// directly (no marching), so it costs little: its pattern, the soft shadows of the objects, contact shadows and a
// reflection of the objects (one more march, blurred by Floor roughness). The objects reflect the floor and the sky
// without a march. The spot light orbits, jumps to a new place at every beat or swings, and flashes on the beat.
// iTime counts beats in Sync. Cost: Quality 1 marches up to 80 steps for the objects, 24 for a shadow and 40 for the
// reflection a pixel; 2 up to 120 / 48 / 64 with ambient occlusion; 3 is 2 with 4x antialiasing (4 times the cost).

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
// Random float in [0,1) for an integer-valued 2D input.
float hash12(vec2 p) {
    uvec2 q = uvec2(ivec2(floor(p)));
    return uintToUnit(pcgHash(q.x + pcgHash(q.y)));
}
// Random vec2 in [0,1)^2 for an integer-valued 2D input.
vec2 hash22(vec2 p) {
    ivec2 q = ivec2(floor(p));
    return uintToUnit(pcg3d(uvec3(q.x, q.y, 0x2545u))).xy;
}

// ---- shader-skills library: sdf3d ----
// Sphere of radius r.
float sdSphere(vec3 p, float r) { return length(p) - r; }
// Box with rounded edges. The outer size stays b; r is the edge radius (r <= min(b)).
float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}
// Wireframe box: edges of a box with half-extents b and edge thickness e.
float sdBoxFrame(vec3 p, vec3 b, float e) {
    p = abs(p) - b;
    vec3 q = abs(p + e) - e;
    return min(min(
        length(max(vec3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(vec3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
        length(max(vec3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
}
// Torus in the XZ plane. t.x = major radius, t.y = tube radius.
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}
// Capsule: segment a-b swept by radius r.
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}
// Vertical capped cylinder from y = -h to y = +h, radius r.
float sdCylinder(vec3 p, float h, float r) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}
// Regular octahedron with "radius" s (vertex distance from center). Bound version.
float sdOctahedron(vec3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

// ---- shader-skills library: operators ----
// Smooth union (polynomial, C1). Blends where |a - b| < k, with a max bulge of k/4.
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ---- shader-skills library: domain ----
// Sector index in [0, n) for domPolar.
float domPolarId(vec2 p, float n) {
    if (dot(p, p) < 1e-20) return 0.0;
    float sector = TAU / n;
    return mod(floor(atan(p.y, p.x) / sector + 0.5), n);
}
// Rotate p into the frame of polar sector id (its center line on +X). domPolarSector(p, domPolarId(p, n), n) equals domPolar(p, n).
vec2 domPolarSector(vec2 p, float id, float n) { return rot2(-id * TAU / n) * p; }

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

// ---- shader ----
//@enum options=(Sphere, Rounded box, Torus, Gem, Pill, Box frame, Cylinder, Blob) value=1
uniform int shape;
//@enum options=(Single, Row, Ring, Grid) value=1
uniform int arrangement;            // Row: 3 copies, Ring: 6 around the middle, Grid: 3 x 3
//@slider min=0.2 max=1.5 value=0.55
uniform float size;
//@slider min=1.0 max=4.0 value=1.8
uniform float spacing;              // between the copies, in sizes
//@slider min=0.0 max=0.4 value=0.1
uniform float roundness;
//@slider min=0.0 max=2.0 value=0.25
uniform float hover;                // height over the floor, in sizes
//@slider min=0.0 max=2.0 value=0.6
uniform float bounce;               // a jump at every beat, in sizes (the copies one after the other)
//@slider min=-2.0 max=2.0 value=0.25
uniform float spin;                 // turns a 4 beats
//@rgb value=(0.95, 0.35, 0.2)
uniform vec3 object_color;
//@rgb value=(0.2, 0.5, 1.0)
uniform vec3 object_color_2;        // the copies go from Object color to this one
//@slider min=0.05 max=1.0 value=0.25
uniform float object_roughness;
//@slider min=0.0 max=1.0 value=0.2
uniform float metallic;
//@slider min=0.0 max=4.0 value=0.0
uniform float glow;                 // the objects light up themselves, in their colour
//@enum options=(Plain, Checker, Grid lines, Tiles, Rings) value=3
uniform int floor_pattern;
//@rgb value=(0.09, 0.09, 0.1)
uniform vec3 floor_color;
//@rgb value=(0.3, 0.3, 0.33)
uniform vec3 floor_color_2;         // the second colour of the pattern
//@slider min=0.1 max=4.0 value=1.0
uniform float tile_size;
//@slider min=0.0 max=1.0 value=0.6
uniform float floor_reflection;
//@slider min=0.0 max=1.0 value=0.25
uniform float floor_roughness;      // blurs and fades the reflection with distance
//@enum options=(Fixed, Orbit, Beat jump, Swing) value=2
uniform int light_motion;           // Beat jump: a new place at every beat; Swing: back and forth over 4 beats
//@slider min=0.0 max=360.0 value=35.0
uniform float light_angle;          // degrees around the stage
//@slider min=-90.0 max=90.0 value=20.0
uniform float light_speed;          // Orbit: degrees a beat
//@slider min=0.5 max=8.0 value=4.5
uniform float light_height;
//@slider min=0.0 max=6.0 value=2.2
uniform float light_distance;       // from the middle of the stage
//@slider min=5.0 max=90.0 value=42.0
uniform float spot_angle;           // degrees: the width of the pool of light
//@rgb value=(1.0, 0.92, 0.8)
uniform vec3 light_color;
//@slider min=0.0 max=10.0 value=5.0
uniform float light_intensity;
//@slider min=0.0 max=1.0 value=0.35
uniform float beat_flash;
//@slider min=2.0 max=32.0 value=10.0
uniform float shadow_sharpness;     // low: soft shadows
//@rgb value=(0.25, 0.4, 1.0)
uniform vec3 rim_color;             // a back light
//@slider min=0.0 max=3.0 value=0.8
uniform float rim;
//@slider min=0.0 max=1.0 value=0.25
uniform float ambient;
//@slider min=2.0 max=16.0 value=6.5
uniform float camera_distance;
//@slider min=-10.0 max=80.0 value=18.0
uniform float camera_height;        // degrees above the floor
//@slider min=0.0 max=360.0 value=20.0
uniform float camera_angle;         // degrees around the stage
//@slider min=-1.0 max=1.0 value=0.05
uniform float camera_orbit;         // turns a 16 beats
//@slider min=0.5 max=3.0 value=1.6
uniform float zoom;
//@rgb value=(0.01, 0.01, 0.02)
uniform vec3 background;            // far away, at the horizon and above
//@slider min=0.0 max=0.3 value=0.06
uniform float fog;
//@int min=1 max=3 value=1
uniform int quality;

// --- the objects ---

// The copy that p belongs to (-1..1 on each axis that is copied) and the point in its frame
vec3 cellOf(vec3 p, out vec2 id) {
    float s = spacing * size * 2.0;
    id = vec2(0.0);
    vec3 q = p;
    if (arrangement == 1) {
        id.x = clamp(floor(p.x / s + 0.5), -1.0, 1.0);
        q.x -= id.x * s;
    } else if (arrangement == 2) {
        float n = 6.0;
        float sid = domPolarId(p.xz, n);
        vec2 r = domPolarSector(p.xz, sid, n);
        q = vec3(r.x - s * 0.9, p.y, r.y);
        id = vec2(sid, 0.0);
    } else if (arrangement == 3) {
        id = clamp(floor(p.xz / s + 0.5), -1.0, 1.0);
        q.xz -= id * s;
    }
    return q;
}

float shapeDist(vec3 p, float r) {
    if (shape == 0) return sdSphere(p, r);
    if (shape == 1) return sdRoundBox(p, vec3(r * 0.78), roundness * r);
    if (shape == 2) return sdTorus(p.xzy, vec2(r * 0.72, r * 0.26 + roundness * 0.2 * r));
    if (shape == 3) return sdOctahedron(p, r * 1.3) - roundness * r * 0.4;
    if (shape == 4) return sdCapsule(p, vec3(0.0, -r * 0.55, 0.0), vec3(0.0, r * 0.55, 0.0), r * 0.45);
    if (shape == 5) return sdBoxFrame(p, vec3(r * 0.8), r * (0.08 + roundness * 0.3)) - roundness * r * 0.15;
    if (shape == 6) return sdCylinder(p, r * 0.8, r * 0.6) - roundness * r * 0.3;
    float t = iTime * 0.5;
    float d = sdSphere(p - vec3(sin(t * 3.1), cos(t * 2.3), sin(t * 1.7)) * r * 0.35, r * 0.55);
    d = smin(d, sdSphere(p - vec3(cos(t * 2.7), sin(t * 1.9), cos(t * 3.3)) * r * 0.4, r * 0.45), r * 0.4);
    return smin(d, sdSphere(p - vec3(sin(t * 1.3 + 2.0), sin(t * 2.9), cos(t * 2.1)) * r * 0.45, r * 0.4), r * 0.4);
}

// Height of a copy over the floor: hover plus the jump of its beat
float lift(vec2 id) {
    float phase = (id.x + 1.0) * 0.12 + (id.y + 1.0) * 0.35;
    float f = fract(iTime - phase);
    float jump = 4.0 * f * (1.0 - f);
    return size * (1.0 + hover + bounce * jump * jump);
}

vec2 map(vec3 p) {
    vec2 id;
    vec3 q = cellOf(p, id);
    q.y -= lift(id);
    float a = iTime * spin * TAU / 4.0 + id.x * 0.7 + id.y * 1.3;
    q.xz = rot2(a) * q.xz;
    q.xy = rot2(0.35 + 0.2 * sin(a * 0.5)) * q.xy;
    // 0.85: a step a little shorter than the distance, so the march does not jump into the copy of the next cell
    float m = 0.0;
    if (arrangement == 1)
        m = (id.x + 1.0) * 0.5;
    else if (arrangement == 2)
        m = abs(mod(id.x, 6.0) - 3.0) / 3.0;
    else if (arrangement == 3)
        m = (id.x + 1.0 + (id.y + 1.0) * 3.0) / 8.0;
    return vec2(shapeDist(q, size) * 0.85, m);
}

vec3 marchObjects(vec3 ro, vec3 rd, float tmax, int maxSteps) {
    float t = 0.02;
    for (int i = 0; i < 160; i++) {
        if (i >= maxSteps)
            break;
        vec2 h = map(ro + rd * t);
        if (abs(h.x) < 0.0006 * t)
            return vec3(t, h.y, 1.0);
        t += h.x;
        if (t > tmax)
            break;
    }
    return vec3(tmax, 0.0, 0.0);
}

float shadowTo(vec3 ro, vec3 rd, float tmax, int maxSteps) {
    float res = 1.0;
    float t = 0.03;
    for (int i = 0; i < 64; i++) {
        if (i >= maxSteps)
            break;
        float h = map(ro + rd * t).x;
        res = min(res, shadow_sharpness * h / t);
        t += clamp(h, 0.02, 0.6);
        if (res < 0.002 || t > tmax)
            break;
    }
    res = clamp(res, 0.0, 1.0);
    return res * res * (3.0 - 2.0 * res);
}

// --- light and floor ---

vec3 lightPos() {
    float a = light_angle;
    if (light_motion == 1)
        a += light_speed * iTime;
    else if (light_motion == 2)
        a += (floor(iTime) + smoothstep(0.0, 0.3, fract(iTime))) * 137.5;
    else if (light_motion == 3)
        a += 60.0 * sin(iTime * PI * 0.5);
    float r = radians(a);
    return vec3(cos(r) * light_distance, light_height, sin(r) * light_distance);
}

float flashNow() {
    return 1.0 + beat_flash * 2.5 * pow(1.0 - fract(iTime), 6.0);
}

// The light of the spot at p: colour * pool * distance falloff, and the direction to it
vec3 spotLight(vec3 p, vec3 lp, out vec3 l, out float dist) {
    vec3 target = vec3(0.0, size, 0.0);
    vec3 axis = normalize(target - lp);
    vec3 d = p - lp;
    dist = length(d);
    l = -d / dist;
    float c = dot(-l, axis);
    float outer = cos(radians(spot_angle));
    float inner = cos(radians(spot_angle * 0.7));
    float pool = smoothstep(outer, inner, c);
    float fall = 16.0 / (4.0 + dist * dist);
    return srgbToLinear(light_color) * light_intensity * flashNow() * pool * fall;
}

// Pattern antialiasing width: the footprint of a pixel on the floor, in tiles (wider far away and at a flat angle)
float fwidthSafe(float t, float rdy) {
    return clamp(t * (2.0 / iResolution.y / zoom) / max(abs(rdy), 0.03) / tile_size, 0.0, 0.5);
}

vec3 floorAlbedo(vec2 xz, float t, float rdy) {
    vec2 g = xz / tile_size;
    float w = fwidthSafe(t, rdy);
    float m = 0.0;
    if (floor_pattern == 1) {
        // a box-filtered checker: it turns grey in the distance instead of flickering
        vec2 fw = vec2(w * 2.0 + 1e-4);
        vec2 i = 2.0 * (abs(fract((g - 0.5 * fw) * 0.5) - 0.5) - abs(fract((g + 0.5 * fw) * 0.5) - 0.5)) / fw;
        m = 0.5 - 0.5 * i.x * i.y;
    } else if (floor_pattern == 2) {
        vec2 f = abs(fract(g) - 0.5);
        m = smoothstep(0.47 - w, 0.47 + w, max(f.x, f.y));
    } else if (floor_pattern == 3) {
        vec2 f = abs(fract(g) - 0.5);
        float grout = smoothstep(0.46 - w, 0.46 + w, max(f.x, f.y));
        float tone = hash12(floor(g)) * 0.35;
        return mix(mix(srgbToLinear(floor_color_2), srgbToLinear(floor_color), tone * 2.0), srgbToLinear(floor_color) * 0.4, grout);
    } else if (floor_pattern == 4) {
        float r = length(xz) / tile_size;
        float f = abs(fract(r) - 0.5);
        m = smoothstep(0.42 - w, 0.42 + w, f);
    }
    return mix(srgbToLinear(floor_color), srgbToLinear(floor_color_2), m);
}

vec3 sky(vec3 rd) {
    vec3 bg = srgbToLinear(background);
    return bg * (0.6 + 0.8 * clamp(1.0 - rd.y * 1.5, 0.0, 1.0));
}

// --- shading ---

vec3 objectColor(float m) {
    return srgbToLinear(mix(object_color, object_color_2, m));
}

// An object at p: key light, rim, ambient and what it reflects (the floor and the sky, no march)
vec3 shadeObject(vec3 p, vec3 n, vec3 rd, float m, bool full) {
    vec3 albedo = objectColor(m);
    vec3 lp = lightPos();
    vec3 l;
    float dist;
    vec3 lc = spotLight(p, lp, l, dist);
    float sh = full ? shadowTo(p + n * 0.01, l, dist, quality >= 2 ? 48 : 24) : 1.0;
    vec3 v = -rd;
    vec3 col = shadePBR(n, v, l, albedo, object_roughness, metallic) * lc * sh;
    float ao = full && quality >= 2 ? calcAO(p, n, size * 0.4) : 1.0;
    // the floor under it lights it a little from below
    col += albedo * ambient * (0.6 + 0.4 * n.y) * ao;
    col += rim_color * rim * pow(clamp(1.0 - dot(n, v), 0.0, 1.0), 3.0) * clamp(0.3 - n.y * 0.7 + 0.7, 0.0, 1.0) * ao;
    // reflection: the floor (straight, no march) or the sky
    vec3 r = reflect(rd, n);
    vec3 env;
    if (r.y < -0.01) {
        float tf = -p.y / r.y;
        vec3 fp = p + r * tf;
        vec3 fl;
        float fd;
        vec3 flc = spotLight(fp, lp, fl, fd);
        env = floorAlbedo(fp.xz, tf, r.y) * (flc * max(fl.y, 0.0) + ambient);
        env = mix(env, sky(r), 1.0 - exp(-fog * fog * tf * tf));
    } else
        env = sky(r);
    vec3 f0 = mix(vec3(0.04), albedo, metallic);
    vec3 fres = fresnelSchlick(max(dot(n, v), 0.0), f0);
    col += env * fres * (1.0 - object_roughness * 0.8) * ao;
    col += albedo * glow;
    return col;
}

vec3 shadeFloor(vec3 p, vec3 rd, float t) {
    vec3 n = vec3(0.0, 1.0, 0.0);
    vec3 albedo = floorAlbedo(p.xz, t, rd.y);
    vec3 lp = lightPos();
    vec3 l;
    float dist;
    vec3 lc = spotLight(p, lp, l, dist);
    float sh = shadowTo(p + n * 0.005, l, dist, quality >= 2 ? 48 : 24);
    float ao = calcAO(p, n, size * 0.8);
    vec3 col = albedo * (lc * max(l.y, 0.0) * sh + ambient * ao);
    // the glow of the objects falls on the floor near them
    if (glow > 0.0) {
        float d = map(p).x;
        col += albedo * objectColor(0.5) * glow * 0.6 * exp(-d * 3.0 / size);
    }
    // the reflection of the objects (and the sky)
    if (floor_reflection > 0.0) {
        vec3 r = reflect(rd, n);
        float fres = 0.04 + 0.96 * pow(1.0 - max(dot(n, -rd), 0.0), 5.0);
        float k = floor_reflection * mix(0.35, 1.0, fres);
        vec3 h = marchObjects(p + n * 0.01, r, 30.0, quality >= 2 ? 64 : 40);
        vec3 refl;
        if (h.z > 0.5) {
            vec3 hp = p + r * h.x;
            vec3 hn = calcNormal(hp, 0.001 * h.x);
            refl = shadeObject(hp, hn, r, h.y, false);
            refl *= exp(-h.x * floor_roughness * 2.5);
        } else
            refl = sky(r) * (1.0 - floor_roughness * 0.5);
        col = mix(col, refl, k * (1.0 - floor_roughness * 0.6));
    }
    return col;
}

vec3 render(vec2 uv) {
    float ca = radians(camera_angle) + iTime * camera_orbit * TAU / 16.0;
    float ch = radians(camera_height);
    vec3 target = vec3(0.0, size * (1.0 + hover), 0.0);
    vec3 ro = target + camera_distance * vec3(cos(ca) * cos(ch), sin(ch), sin(ca) * cos(ch));
    ro.y = max(ro.y, 0.05);
    mat3 cam = cameraMatrix(ro, target, 0.0);
    vec3 rd = cameraRay(cam, uv, zoom);

    float tFloor = rd.y < 0.0 ? -ro.y / rd.y : 1e9;
    int steps = quality >= 2 ? 120 : 80;
    vec3 hit = marchObjects(ro, rd, min(tFloor, 40.0), steps);
    vec3 col;
    float t;
    if (hit.z > 0.5) {
        t = hit.x;
        vec3 p = ro + rd * t;
        vec3 n = calcNormal(p, 0.0005 * t);
        col = shadeObject(p, n, rd, hit.y, true);
    } else if (tFloor < 1e8) {
        t = tFloor;
        col = shadeFloor(ro + rd * t, rd, t);
    } else {
        return sky(rd);
    }
    return mix(col, sky(rd), 1.0 - exp(-fog * fog * t * t));
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
            col += tonemapAgX(render(uv));
        }
    }
    col /= float(aa * aa);
    col = linearToSrgb(col) + ditherTPDF(fragCoord, iFrame);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
