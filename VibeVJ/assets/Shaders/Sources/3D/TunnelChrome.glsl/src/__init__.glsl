//@settings dtype=float32 format=rgba

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

// ---- shader-skills library: sdf2d ----
// Rectangle with half-extents b and per-corner radii r = (top-right, bottom-right, top-left, bottom-left).
float sdRoundedBox(vec2 p, vec2 b, vec4 r) {
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x = (p.y > 0.0) ? r.x : r.y;
    vec2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
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
// Split-sum environment specular without a lookup texture (Karis 2014, after Lazarov). Multiply by the sky or environment color in the reflection direction.
vec3 envBRDFApprox(vec3 f0, float NoV, float roughness) {
    vec4 r = roughness * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
    float a = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    vec2 ab = vec2(-1.04, 1.04) * a + r.zw;
    return f0 * ab.x + ab.y;
}

// ---- shader-skills library: color ----
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
// TunnelChrome: a flight through a raymarched metal pipe tunnel: polished ribs with lamps in them, pipes along the
// floor, panels with seams, oil grime and rust in the corners. The metal reflects the tunnel (traced from quality 2
// on), lights race past on every beat and glow in the haze, the camera banks into the bends. Time counts beats in Sync.

//@enum options=(Chrome, Brass, Copper, Black steel, Titanium) value=0
uniform int metal;
//@slider min=0.0 max=1.0 value=0.12
uniform float roughness;      // of the clean metal; grime makes it rougher
//@slider min=0.0 max=1.0 value=0.45
uniform float grime;          // oil and dust in the corners and on the floor
//@slider min=0.0 max=1.0 value=0.2
uniform float rust;           // rust streaks running down from the seams
//@slider min=1.2 max=4.0 value=2.0
uniform float tube_radius;    // metres
//@slider min=0.6 max=6.0 value=2.6
uniform float rib_spacing;    // metres between the ribs
//@slider min=0.0 max=0.7 value=0.25
uniform float rib_depth;      // how far the ribs stand out of the wall
//@int min=0 max=6 value=3
uniform int pipes;            // pipes running along the floor
//@rgb value=(0.55, 0.75, 1.0)
uniform vec3 lamp_color;      // the lamps in the ribs
//@slider min=0.0 max=4.0 value=1.2
uniform float lamp_glow;
//@int min=1 max=8 value=2
uniform int lamp_every;       // every how many ribs carries a lamp
//@rgb value=(1.0, 0.42, 0.12)
uniform vec3 light_color;     // the beat lights
//@rgb value=(0.25, 0.55, 1.0)
uniform vec3 light_color_b;   // every second beat light
//@slider min=0.0 max=1.0 value=0.5
uniform float lamp_flicker;   // the lamps flicker a little, like old tubes

// ---- Flight, camera, look (the same controls in every tunnel) ----
//@slider min=0.0 max=4.0 value=1.0
uniform float speed;          // multiplies the time; the time counts beats in Sync
//@slider min=0.0 max=8.0 value=1.5
uniform float fly_speed;      // metres per beat
//@slider min=0.0 max=2.0 value=1.0
uniform float curves;         // how much the tunnel bends
//@slider min=0.0 max=2.0 value=0.6
uniform float banking;        // the camera leans into the bends
//@slider min=-1.0 max=1.0 value=0.0
uniform float roll_speed;     // turns of the camera per 32 beats
//@slider min=40.0 max=120.0 value=75.0
uniform float fov;            // field of view in degrees
//@slider min=0.0 max=1.0 value=0.5
uniform float fog;            // haze along the tunnel
//@slider min=0.0 max=2.0 value=1.0
uniform float beat_lights;    // brightness of the lights that race past on every beat
//@slider min=0.0 max=40.0 value=16.0
uniform float light_speed;    // metres per beat the beat lights travel towards the camera
//@slider min=-3.0 max=3.0 value=0.0
uniform float exposure;       // in stops
//@slider min=0.05 max=1.0 value=1.0
uniform float brightness;     // the brightest white (LED walls: often 0.5 is plenty)
//@int min=1 max=3 value=1
uniform int quality;          // 1 live at 1080p, 2 adds traced reflections and AO, 3 adds shadows and more steps
//@enum options=(Final, Normals, Steps, Depth, Material) value=0
uniform int debug_view;

// The tunnel repeats itself after LOOP metres, so the flight never runs out of precision; every pattern along it
// repeats with a period that divides LOOP.
const float LOOP = 256.0;

// A spacing along the tunnel made to fit LOOP a whole number of times (count times, when given), so the flight
// passes the seam of the loop without a jump.
float loopFit(float spacing, float count) {
    return LOOP / (max(1.0, floor(LOOP / (spacing * count) + 0.5)) * count);
}
// A frequency (radians per metre) along the tunnel that fits LOOP.
float loopFreq(float f) { return TAU * floor(f * LOOP / TAU + 0.5) / LOOP; }

// Centre line of the tunnel at depth z (x, y), and its second derivative (the bend, for banking).
vec2 tunnelPath(float z) {
    float w = TAU / LOOP;
    return curves * vec2(2.2 * sin(z * w * 3.0) + 0.9 * sin(z * w * 7.0 + 1.0),
                         1.2 * sin(z * w * 4.0 + 0.5) + 0.5 * cos(z * w * 9.0));
}
vec2 tunnelBend(float z) {
    float w = TAU / LOOP;
    return -curves * vec2(2.2 * 9.0 * w * w * sin(z * w * 3.0) + 0.9 * 49.0 * w * w * sin(z * w * 7.0 + 1.0),
                          1.2 * 16.0 * w * w * sin(z * w * 4.0 + 0.5) + 0.5 * 81.0 * w * w * cos(z * w * 9.0));
}

// Value noise whose lattice repeats every period.x cells in x (around the tunnel) and period.y cells in z (along
// it), so the textures close around the tunnel and loop with it.
float pnoise(vec3 p, vec2 period) {
    vec3 i = floor(p);
    vec3 f = p - i;
    vec3 u = f * f * (3.0 - 2.0 * f);
    float a = 0.0;
    for (int k = 0; k < 8; k++) {
        vec3 o = vec3(float(k & 1), float((k >> 1) & 1), float((k >> 2) & 1));
        vec3 c = i + o;
        c.x = mod(c.x, period.x);
        c.z = mod(c.z, period.y);
        float h = hash13(c);
        vec3 w = mix(1.0 - u, u, o);
        a += h * w.x * w.y * w.z;
    }
    return a;
}
float pfbm(vec3 p, vec2 period, int octaves) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < octaves; i++) {
        s += a * pnoise(p, period);
        p = p * 2.0 + vec3(17.1, 3.7, 0.0);
        period *= 2.0;
        a *= 0.5;
    }
    return s;
}

// Light scattered towards the eye along a ray of length tmax by a point light at lp in thin fog (1 / d^2 law).
float inscatter(vec3 ro, vec3 rd, vec3 lp, float tmax) {
    vec3 q = ro - lp;
    float b = dot(rd, q);
    float h = sqrt(max(dot(q, q) - b * b, 1e-4));
    return (atan((tmax + b) / h) - atan(b / h)) / h;
}

// Depth of the camera (wraps every LOOP metres) and the camera of this frame.
float flightZ(float t) { return mod(fly_speed * t, LOOP); }

// The camera of this frame. yScale flattens the bends up and down (a tunnel with a level floor), lift moves the
// camera off the centre line.
void tunnelCamera(vec2 fragCoord, float t, float yScale, vec2 lift, out vec3 ro, out vec3 rd, out float zc) {
    zc = flightZ(t);
    vec2 sy = vec2(1.0, yScale);
    ro = vec3(tunnelPath(zc) * sy + lift, zc);
    vec3 ta = vec3(tunnelPath(zc + 3.0) * sy + lift, zc + 3.0);
    float roll = -banking * tunnelBend(zc + 1.5).x * 9.0 + TAU * roll_speed * t / 32.0;
    mat3 cam = cameraMatrix(ro, ta, roll);
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    rd = cameraRay(cam, uv, 1.0 / tan(radians(fov) * 0.5));
}

// Depth of beat light i (0 = the newest): born far ahead on its beat, it races towards and past the camera.
// Returns vec2(z, intensity).
vec2 beatLight(int i, float t, float zc) {
    float age = fract(t) + float(i);
    float z = zc + 34.0 - age * light_speed;
    return vec2(z, beat_lights * exp(-0.6 * age) * smoothstep(0.0, 0.08, age));
}

// Linear light -> display: exposure, AgX, sRGB, dither, the brightest white.
vec3 tunnelOutput(vec3 col, vec2 fragCoord) {
    col *= exp2(exposure);
    col = linearToSrgb(tonemapAgX(col)) * brightness;
    return col + ditherTPDF(fragCoord, iFrame);
}

vec3 metalColor() {
    if (metal == 1) return vec3(0.91, 0.72, 0.38);
    if (metal == 2) return vec3(0.95, 0.58, 0.42);
    if (metal == 3) return vec3(0.10, 0.10, 0.11);
    if (metal == 4) return vec3(0.62, 0.60, 0.58);
    return vec3(0.92, 0.93, 0.95);
}

// The rib spacing, fitted so the ribs and their lamps repeat with the loop of the tunnel.
float RS() { return loopFit(rib_spacing, float(lamp_every)); }

float pipeAngle(float i) { return -0.5 * PI + (i - 0.5 * float(pipes - 1)) * 0.36; }

vec2 map(vec3 p) {
    vec2 q = p.xy - tunnelPath(p.z);
    float r = length(q);
    float R = tube_radius;
    float d = R - r;                             // the wall (we are inside)
    float mat = 1.0;
    float zf = mod(p.z, RS()) - 0.5 * RS();
    if (rib_depth > 0.0) {
        float rib = sdRoundedBox(vec2(r - (R - 0.5 * rib_depth) - 0.05, zf), vec2(0.5 * rib_depth + 0.05, 0.13), vec4(0.05));
        if (rib < d) { d = rib; mat = 2.0; }
    }
    if (pipes > 0) {
        float a = atan(q.y, q.x);
        float i = clamp(floor((a + 0.5 * PI) / 0.36 + 0.5 * float(pipes - 1) + 0.5), 0.0, float(pipes - 1));
        float pr = 0.15 + 0.05 * mod(i, 2.0);
        vec2 c = (R - pr - 0.03) * vec2(cos(pipeAngle(i)), sin(pipeAngle(i)));
        float dp = length(q - c) - pr;
        if (dp < d) { d = dp; mat = 3.0; }
    }
    return vec2(d, mat);
}

// Sphere tracing with a step limit from the quality.
vec3 march(vec3 ro, vec3 rd, float tmax, int steps) {
    float t = 0.02;
    for (int i = ZERO; i < 200; i++) {
        if (i >= steps) break;
        vec2 h = map(ro + rd * t);
        if (abs(h.x) < 0.0006 * t + 0.0005) return vec3(t, h.y, float(i));
        t += h.x * 0.85;
        if (t > tmax) break;
    }
    return vec3(-1.0, 0.0, float(steps));
}

// Lamp light on a rib (0..1) at depth z.
float lampAt(float z, float t) {
    float k = floor(z / RS());
    if (mod(k, float(lamp_every)) > 0.5) return 0.0;
    float fl = 1.0 - lamp_flicker * 0.6 * step(0.93, hash12(vec2(mod(k, floor(LOOP / RS() + 0.5)), floor(t * 8.0))));
    return fl;
}

void material(vec3 p, inout vec3 n, float mat, float t, out vec3 albedo, out float rough, out float metallic, out vec3 emit) {
    vec2 q = p.xy - tunnelPath(p.z);
    float r = length(q);
    float a = atan(q.y, q.x);
    float zf = mod(p.z, RS()) - 0.5 * RS();
    // texture coordinates around (u, metres) and along the tunnel (z)
    float n1 = pfbm(vec3((a / TAU + 0.5) * 48.0, r * 4.0, p.z * 3.0), vec2(48.0, LOOP * 3.0), 4);
    float floorish = smoothstep(0.2, -0.9, q.y / max(r, 1e-3));      // dirt collects at the bottom
    float crevice = 0.0;
    if (mat == 1.0) crevice = smoothstep(0.55, 0.05, abs(zf) - 0.13);  // next to the ribs
    if (mat == 3.0) crevice = 0.6;
    float g = smoothstep(0.42, 0.52, grime * (0.5 * floorish + 0.6 * crevice + 1.2 * (n1 - 0.25)));
    albedo = metalColor();
    metallic = 1.0;
    rough = roughness;
    emit = vec3(0.0);
    if (mat == 1.0) {
        // panels: seams around and along, brushed lines
        float seamA = abs(fract(a / TAU * 12.0) - 0.5);
        float seamZ = abs(zf);
        float seam = 1.0 - smoothstep(0.0, 0.012, min(seamA * TAU / 12.0 * r, abs(seamZ - 0.5 * RS() * 0.5)));
        albedo *= 0.5 * (1.0 - 0.6 * seam);       // the panels are darker, duller steel than the ribs
        rough = rough + 0.18;
        // rivets along the seams around the tunnel
        vec2 rv = vec2(fract(a / TAU * 12.0 + 0.5) - 0.5, fract(p.z / RS() * 4.0) - 0.5);
        albedo *= 1.0 - 0.5 * (1.0 - smoothstep(0.018, 0.03, length(rv * vec2(TAU / 12.0 * r, RS() * 0.25))));
        // diamond tread plate on the floor: raised bars, alternately turned, as a bent normal
        float onFloor = smoothstep(-0.55, -0.7, q.y / max(r, 1e-3));
        if (onFloor > 0.0) {
            vec2 uv = vec2(a * r, p.z) / loopFit(0.12, 2.0);
            vec2 id = floor(uv);
            vec2 f = fract(uv) - 0.5;
            float s = mod(id.x + id.y, 2.0) < 0.5 ? 1.0 : -1.0;
            vec2 b = vec2(f.x + s * f.y, f.y - s * f.x) * 0.7071;
            float hgt = max(0.0, 1.0 - (b.x / 0.32) * (b.x / 0.32) - (b.y / 0.07) * (b.y / 0.07));
            vec2 gb = -2.0 * vec2(b.x / (0.32 * 0.32), b.y / (0.07 * 0.07)) * step(0.0, hgt);
            vec2 g2 = vec2(gb.x - s * gb.y, s * gb.x + gb.y) * 0.7071;   // back to (around, along)
            vec3 tu = normalize(vec3(-q.y, q.x, 0.0));
            n = normalize(n - onFloor * 0.005 * (g2.x * tu + g2.y * vec3(0.0, 0.0, 1.0)));
            albedo *= mix(1.0, 1.25, onFloor);
            rough = mix(rough, roughness + 0.25, onFloor);
        }
        // rust streaks run down from the seams
        float streak = pfbm(vec3((a / TAU + 0.5) * 256.0, 0.0, p.z * 0.5), vec2(256.0, LOOP * 0.5), 3)
                     * smoothstep(0.2, -0.6, q.y / max(r, 1e-3) + 0.4);
        float rr = smoothstep(0.55, 0.75, streak) * rust;
        albedo = mix(albedo, vec3(0.35, 0.12, 0.04), rr);
        metallic = mix(metallic, 0.0, rr);
        rough = mix(rough, 0.8, rr);
    } else if (mat == 2.0) {
        // a lamp strip on the inner face of the rib
        float inner = smoothstep(tube_radius - rib_depth + 0.06, tube_radius - rib_depth - 0.02, r);
        float strip = (1.0 - smoothstep(0.02, 0.045, abs(zf))) * inner;
        emit = lamp_color * lamp_glow * 2.5 * strip * lampAt(p.z, t);
        rough *= 0.6;
        // bolts on the sides of the rib
        vec2 bq = vec2(fract(a / TAU * 36.0) - 0.5, (r - tube_radius + rib_depth * 0.3) * 6.0);
        float bolt = 1.0 - smoothstep(0.18, 0.24, length(bq));
        albedo *= 1.0 - 0.7 * bolt * (1.0 - smoothstep(0.0, 0.2, abs(n.z) - 0.8));
    } else {
        albedo = mix(albedo, albedo * vec3(0.9, 0.85, 0.8), 0.5);
        rough = roughness + 0.08;
    }
    float speck = pnoise(vec3((a / TAU + 0.5) * 512.0, r * 30.0, p.z * 30.0), vec2(512.0, LOOP * 30.0));
    g = clamp(g * (0.55 + 0.45 * speck), 0.0, 1.0);
    albedo = mix(albedo, vec3(0.05, 0.04, 0.03), g * 0.85);
    metallic = mix(metallic, 0.3, g);
    rough = clamp(mix(rough, 0.7, g), 0.03, 1.0);
    // a beat light passing lights up the lamps it flies by
    for (int i = 0; i < 3; i++) {
        vec2 bl = beatLight(i, t, flightZ(t));
        float near = exp(-abs(p.z - bl.x) * 1.2);
        vec3 lc = mod(floor(t) - float(i), 2.0) < 0.5 ? light_color : light_color_b;
        if (mat == 2.0) emit += lc * bl.y * near * 6.0 * smoothstep(tube_radius - rib_depth + 0.06, tube_radius - rib_depth - 0.02, r);
    }
}

// Light that reaches a surface point directly: beat lights, the lamps, a little light from the camera.
vec3 directLight(vec3 p, vec3 n, vec3 v, vec3 albedo, float rough, float metallic, float t, vec3 camPos, float shadowQ) {
    vec3 col = vec3(0.0);
    float zc = flightZ(t);
    for (int i = 0; i < 3; i++) {
        vec2 bl = beatLight(i, t, zc);
        vec3 lp = vec3(tunnelPath(bl.x), bl.x);
        vec3 l = lp - p;
        float d2 = dot(l, l);
        l /= sqrt(d2);
        vec3 lc = mod(floor(t) - float(i), 2.0) < 0.5 ? light_color : light_color_b;
        float sh = 1.0;
        if (shadowQ > 0.0 && bl.y > 0.02) sh = softShadow(p + n * 0.02, l, 0.02, sqrt(d2), 12.0);
        col += shadePBR(n, v, l, albedo, rough, metallic) * lc * bl.y * 6.0 / (1.0 + d2) * sh;
    }
    // the nearest lamp ribs, as a light ring around the axis
    float k0 = floor(p.z / (RS() * float(lamp_every)) + 0.5) * RS() * float(lamp_every);
    for (int j = -1; j <= 1; j++) {
        float lz = k0 + float(j) * RS() * float(lamp_every) + 0.5 * RS() - 0.5 * RS();
        float lzc = floor(lz / RS()) * RS() + 0.5 * RS();
        vec2 c = tunnelPath(lzc);
        vec2 q = p.xy - c;
        float rr = length(q);
        // the nearest point of the lamp ring (radius of the inner rib face)
        vec3 lp = vec3(c + q / max(rr, 1e-3) * (tube_radius - rib_depth), lzc);
        vec3 l = lp - p;
        float d2 = dot(l, l) + 0.05;
        l /= sqrt(d2);
        col += shadePBR(n, v, l, albedo, rough, metallic) * lamp_color * lamp_glow * lampAt(lzc, t) * 0.25 / (d2 + 0.4);
    }
    vec3 lh = normalize(camPos - p);
    col += shadePBR(n, v, lh, albedo, rough, metallic) * vec3(0.9, 0.95, 1.0) * 0.12 / (1.0 + dot(camPos - p, camPos - p) * 0.3);
    return col;
}

// Haze and the glow of the beat lights in it along a ray of length tl.
vec3 haze(vec3 col, vec3 ro, vec3 rd, float tl, float t) {
    float fogAmt = 1.0 - exp(-fog * 0.12 * tl);
    vec3 fogCol = lamp_color * lamp_glow * 0.012;
    col = mix(col, fogCol, fogAmt);
    float zc = flightZ(t);
    for (int i = 0; i < 3; i++) {
        vec2 bl = beatLight(i, t, zc);
        vec3 lp = vec3(tunnelPath(bl.x), bl.x);
        vec3 lc = mod(floor(t) - float(i), 2.0) < 0.5 ? light_color : light_color_b;
        col += lc * bl.y * (0.01 + fog * 0.12) * inscatter(ro, rd, lp, tl);
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float t = iTime * speed;
    vec3 ro, rd;
    float zc;
    tunnelCamera(fragCoord, t, 1.0, vec2(0.0), ro, rd, zc);
    int steps = quality >= 3 ? 140 : (quality == 2 ? 100 : 72);
    float tmax = 60.0;
    vec3 h = march(ro, rd, tmax, steps);
    float tl = h.x < 0.0 ? tmax : h.x;
    vec3 col = vec3(0.0);
    if (h.x > 0.0) {
        vec3 p = ro + rd * h.x;
        vec3 n = calcNormal(p, 0.0005 * h.x + 0.0008);
        vec3 v = -rd;
        vec3 albedo, emit;
        float rough, metallic;
        material(p, n, h.y, t, albedo, rough, metallic, emit);
        float ao = quality >= 2 ? calcAO(p, n, 0.35) : clamp(0.4 + 2.0 * map(p + n * 0.25).x, 0.0, 1.0);
        col = directLight(p, n, v, albedo, rough, metallic, t, ro, quality >= 3 ? 1.0 : 0.0) * mix(0.5, 1.0, ao) + emit;
        // reflection: trace the mirrored ray, shade what it hits with direct light, blur it by the roughness
        vec3 f0 = mix(vec3(0.04), albedo, metallic);
        float NoV = max(dot(n, v), 0.0);
        vec3 spec = envBRDFApprox(f0, NoV, rough);
        vec3 rdr = reflect(rd, n);
        vec3 refl = vec3(0.0);
        vec3 rh = march(p + n * 0.01, rdr, 24.0, quality >= 2 ? 64 : 28);
        float rl = rh.x < 0.0 ? 24.0 : rh.x;
        if (rh.x > 0.0) {
            vec3 rp = p + n * 0.01 + rdr * rh.x;
            vec3 rn = calcNormal(rp, 0.002 + 0.001 * rh.x);
            vec3 ra, re;
            float rr, rm;
            material(rp, rn, rh.y, t, ra, rr, rm, re);
            // metal seen in metal: its own reflection is approximated by the lamp colour
            refl = directLight(rp, rn, -rdr, ra, max(rr, 0.35), rm * 0.6, t, ro, 0.0) + re
                 + ra * rm * lamp_color * lamp_glow * 0.02;
        }
        refl = haze(refl, p, rdr, rl, t);
        float blur = smoothstep(0.1, 0.8, rough);
        vec3 envAvg = lamp_color * lamp_glow * 0.03 + light_color * beat_lights * 0.03 * exp(-fract(t));
        col += spec * mix(refl, envAvg, blur * 0.7) * ao;
        if (debug_view == 1) col = n * 0.5 + 0.5;
        if (debug_view == 4) col = h.y == 1.0 ? vec3(0.6) : (h.y == 2.0 ? vec3(0.9, 0.5, 0.2) : vec3(0.2, 0.6, 0.9));
    }
    col = haze(col, ro, rd, tl, t);
    if (debug_view == 2) col = vec3(h.z / float(steps));
    if (debug_view == 3) col = vec3(1.0 - tl / tmax);
    if (debug_view > 0) { fragColor = vec4(col, 1.0); return; }
    fragColor = vec4(tunnelOutput(col, fragCoord), 1.0);
}
