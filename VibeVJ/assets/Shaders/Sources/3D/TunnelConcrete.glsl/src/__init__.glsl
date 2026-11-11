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
// Random float in [0,1) for an integer-valued input.
float hash11(float p) { return uintToUnit(pcgHash(uint(int(floor(p))))); }
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

// ---- shader-skills library: noise ----
// Interleaved gradient noise: cheap per-pixel noise whose 3x3 neighborhoods are nearly stratified. Not a hash. pixel must be integer pixel coordinates (floor(fragCoord)). The frame overload animates it for accumulation and TAA.
float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}
float interleavedGradientNoise(vec2 pixel, int frame) {
    return interleavedGradientNoise(pixel + 5.588238 * float(frame % 64));
}

// ---- shader-skills library: sdf3d ----
// Axis-aligned box with half-extents b.
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// ---- shader-skills library: sdf2d ----
// Axis-aligned rectangle with half-extents b.
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
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

// ---- shader-skills library: volume ----
// Henyey-Greenstein phase function. g in (-1, 1): > 0 forward (silver linings), < 0 backward.
float phaseHG(float mu, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-6), 1.5));
}

// ---- shader-skills library: post ----
// Triangular-PDF dither of +-1 LSB for 8-bit output. Add AFTER linearToSrgb, right before writing fragColor.
vec3 ditherTPDF(vec2 fragCoord, int frame) {
    vec2 r = hash22(vec2(floor(fragCoord) + 7919.0 * float(frame % 1024)));
    return vec3((r.x + r.y - 1.0) / 255.0);
}

// ---- shader ----
// TunnelConcrete: a flight through a raymarched brutalist concrete tunnel: board-marked walls with tie holes and
// stains, pillars and ceiling beams, slots in the ceiling that let shafts of light fall through the haze, a wet floor
// whose puddles mirror the tunnel (traced). Strip lights along the walls chase on the beat, lights race past.
// Time counts beats in Sync.

//@slider min=1.4 max=4.0 value=2.3
uniform float tunnel_width;   // half the width, metres
//@slider min=2.0 max=6.0 value=4.0
uniform float bay_length;     // metres from pillar to pillar (one ceiling slot each)
//@slider min=0.0 max=1.0 value=0.6
uniform float wetness;        // puddles on the floor; 1 = the whole floor is a mirror
//@slider min=0.0 max=1.0 value=0.5
uniform float stains;         // water stains running down the walls
//@rgb value=(0.56, 0.55, 0.52)
uniform vec3 concrete_color;
//@rgb value=(1.0, 0.84, 0.6)
uniform vec3 shaft_color;     // the light falling through the slots
//@slider min=0.0 max=4.0 value=1.5
uniform float shaft_light;
//@slider min=0.0 max=1.0 value=0.35
uniform float shaft_angle;    // how steep the light falls; 0 = straight down
//@slider min=0.0 max=2.0 value=1.0
uniform float dust;           // dust in the shafts, drifting
//@rgb value=(0.15, 0.85, 1.0)
uniform vec3 strip_color;     // the strip lights along the walls
//@slider min=0.0 max=4.0 value=1.0
uniform float strip_glow;
//@enum options=(Steady, Chase on the beat, Flash on the beat, Off) value=1
uniform int strip_mode;
//@rgb value=(0.75, 0.88, 1.0)
uniform vec3 light_color;     // the beat lights
//@rgb value=(1.0, 0.22, 0.25)
uniform vec3 light_color_b;   // every second beat light

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

const float FLOOR_Y = -1.4;
const float CEIL_Y = 1.7;
const float Y_SCALE = 0.15;

// The bay length, fitted so the bays repeat with the loop of the tunnel.
float BL() { return loopFit(bay_length, 1.0); }

vec2 centre(float z) { return tunnelPath(z) * vec2(1.0, Y_SCALE); }

vec2 map(vec3 p) {
    vec2 c = centre(p.z);
    vec3 q = vec3(p.xy - c, p.z);
    float W = tunnel_width;
    float zb = mod(p.z, BL()) - 0.5 * BL();         // 0 in the middle of a bay
    float zp = mod(p.z + 0.5 * BL(), BL()) - 0.5 * BL();  // 0 at a pillar
    // free space: between the walls, above the floor, below the ceiling or up in the slot
    float slot = -sdBox(vec3(q.x, q.y - CEIL_Y - 2.0, zb), vec3(0.5, 2.0, 0.17 * BL()));
    float ceilF = max(CEIL_Y - q.y, slot);
    float d = min(W - abs(q.x), ceilF);
    float mat = 1.0;
    float fl = q.y - FLOOR_Y;
    if (fl < d) { d = fl; mat = 2.0; }
    if (ceilF < W - abs(q.x) && ceilF <= fl) mat = 3.0;
    // pillars on both walls and the beam across the ceiling between them
    float pil = sdBox(vec3(abs(q.x) - W, q.y, zp), vec3(0.32, 4.0, 0.28));
    float beam = sdBox(vec3(q.x, q.y - CEIL_Y + 0.22, zp), vec3(W, 0.28, 0.26));
    float pb = min(pil, beam);
    if (pb < d) { d = pb; mat = 4.0; }
    // a low step along both walls that holds the strip lights
    float kerb = sdBox(vec3(abs(q.x) - W, q.y - FLOOR_Y, zp), vec3(0.18, 0.16, 0.5 * BL()));
    if (kerb < d) { d = kerb; mat = 5.0; }
    return vec2(d, mat);
}

vec3 march(vec3 ro, vec3 rd, float tmax, int steps) {
    float t = 0.02;
    for (int i = ZERO; i < 200; i++) {
        if (i >= steps) break;
        vec2 h = map(ro + rd * t);
        if (abs(h.x) < 0.0006 * t + 0.0005) return vec3(t, h.y, float(i));
        t += h.x * 0.9;
        if (t > tmax) break;
    }
    return vec3(-1.0, 0.0, float(steps));
}

vec3 sunDir() { return normalize(vec3(0.15, 1.0, 0.9 * shaft_angle)); }

// How much of the light from the slots reaches p (0..1): follow the light up to the ceiling and look whether it
// comes through a slot there.
float shaftVis(vec3 p) {
    vec2 c = centre(p.z);
    vec3 L = sunDir();
    float s = (CEIL_Y - (p.y - c.y)) / L.y;
    if (s < 0.0) return 1.0;
    vec3 h = p + L * s;
    vec2 ch = centre(h.z);
    float zb = mod(h.z, BL()) - 0.5 * BL();
    float inX = smoothstep(0.5, 0.4, abs(h.x - ch.x));
    float inZ = smoothstep(0.17 * BL(), 0.17 * BL() - 0.1, abs(zb));
    return inX * inZ;
}

// Strip light brightness at depth z on side sgn (beat chase / flash).
float stripAt(float z, float sgn, float t) {
    if (strip_mode == 3) return 0.0;
    if (strip_mode == 0) return 1.0;
    if (strip_mode == 2) return 0.15 + 2.0 * exp(-6.0 * fract(t));
    // chase: a bright segment runs along the tunnel on every beat, the sides take turns
    float zc = flightZ(t);
    float run = zc + 20.0 - fract(t) * 30.0;
    float side = mod(floor(t), 2.0) < 0.5 ? 1.0 : -1.0;
    return 0.12 + 2.5 * exp(-abs(z - run) * 0.6) * (sgn == side ? 1.0 : 0.25);
}

void material(vec3 p, inout vec3 n, float mat, float t, out vec3 albedo, out float rough, out vec3 emit, out float wet) {
    vec2 c = centre(p.z);
    vec3 q = vec3(p.xy - c, p.z);
    albedo = srgbToLinear(concrete_color);
    rough = 0.85;
    emit = vec3(0.0);
    wet = 0.0;
    float big = pfbm(vec3(q.x * 1.5, q.y * 1.5, p.z * 1.5), vec2(64.0, LOOP * 1.5), 4);
    float fine = pnoise(vec3(q.x * 18.0, q.y * 18.0, p.z * 18.0), vec2(64.0, LOOP * 18.0));
    albedo *= 0.75 + 0.35 * big + 0.12 * (fine - 0.5);
    if (mat == 1.0 || mat == 4.0) {
        // board marks: horizontal planks of the formwork, tie holes in a grid, stains running down
        float along = mat == 1.0 ? p.z : q.x + p.z;
        float board = abs(fract(q.y / 0.3) - 0.5);
        albedo *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.04, 0.5 - board));
        albedo *= 1.0 - 0.06 * hash11(floor(q.y / 0.3) + 7.0);
        vec2 tie = vec2(fract(along / loopFit(0.9, 1.0)) - 0.5, fract(q.y / 0.6 + 0.25) - 0.5) * vec2(0.9, 0.6);
        albedo *= 1.0 - 0.6 * (1.0 - smoothstep(0.018, 0.028, length(tie)));
        float streak = pfbm(vec3(along * 3.0, 0.0, q.y * 0.15 + 3.0), vec2(64.0, LOOP * 3.0), 3);
        float st = stains * smoothstep(0.45, 0.75, streak) * smoothstep(FLOOR_Y + 3.4, FLOOR_Y + 1.0, q.y);
        albedo *= 1.0 - 0.5 * st;
        rough -= 0.3 * st;
        // the wall is wet just above the floor
        float damp = smoothstep(FLOOR_Y + 0.6, FLOOR_Y, q.y);
        albedo *= 1.0 - 0.35 * damp;
        rough -= 0.3 * damp;
    } else if (mat == 2.0) {
        // the floor: a drain in the middle, puddles where it is wet
        float drain = 1.0 - smoothstep(0.08, 0.1, abs(q.x));
        float pud = pfbm(vec3(q.x * 0.75, 0.0, p.z * 0.75), vec2(64.0, LOOP * 0.75), 4);
        wet = smoothstep(0.62 - wetness * 0.5, 0.66 - wetness * 0.5, pud + 0.1 * drain);
        wet = max(wet, wetness * wetness);
        albedo *= mix(1.0, 0.45, wet);
        albedo *= 1.0 - 0.6 * drain;
        rough = mix(0.8, 0.04, wet);
        // the edges of the puddles stay a little rough
        rough = mix(rough, 0.3, (1.0 - abs(wet * 2.0 - 1.0)) * 0.6);
    } else if (mat == 3.0) {
        albedo *= 0.8;
    } else if (mat == 5.0) {
        // the strip light on the inner face of the low step
        float face = smoothstep(0.5, 0.9, abs(n.x));
        float band = 1.0 - smoothstep(0.03, 0.05, abs(q.y - FLOOR_Y - 0.08));
        float sgn = q.x > 0.0 ? 1.0 : -1.0;
        emit = srgbToLinear(strip_color) * strip_glow * 6.0 * band * face * stripAt(p.z, sgn, t);
        albedo *= 0.5;
    }
    rough = clamp(rough, 0.03, 1.0);
}

vec3 beatLightPos(int i, float t, out vec3 lc, out float inten) {
    vec2 bl = beatLight(i, t, flightZ(t));
    lc = mod(floor(t) - float(i), 2.0) < 0.5 ? srgbToLinear(light_color) : srgbToLinear(light_color_b);
    inten = bl.y;
    return vec3(centre(bl.x) + vec2(0.0, CEIL_Y - 0.6), bl.x);
}

vec3 directLight(vec3 p, vec3 n, vec3 v, vec3 albedo, float rough, float t, float shadowQ) {
    vec3 col = vec3(0.0);
    // the light through the slots
    vec3 L = sunDir();
    float vis = shaftVis(p);
    col += shadePBR(n, v, L, albedo, rough, 0.0) * srgbToLinear(shaft_color) * shaft_light * 1.4 * vis;
    // the beat lights under the ceiling
    for (int i = 0; i < 3; i++) {
        vec3 lc; float inten;
        vec3 lp = beatLightPos(i, t, lc, inten);
        vec3 l = lp - p;
        float d2 = dot(l, l);
        l /= sqrt(d2);
        float sh = 1.0;
        if (shadowQ > 0.0 && inten > 0.02) sh = softShadow(p + n * 0.02, l, 0.02, sqrt(d2), 16.0);
        col += shadePBR(n, v, l, albedo, rough, 0.0) * lc * inten * 9.0 / (1.0 + 0.5 * d2) * sh;
    }
    // the strip lights: a soft light from both walls near the floor
    vec2 c = centre(p.z);
    for (int s = 0; s < 2; s++) {
        float sgn = s == 0 ? 1.0 : -1.0;
        vec3 lp = vec3(c.x + sgn * (tunnel_width - 0.2), c.y + FLOOR_Y + 0.1, p.z);
        vec3 l = lp - p;
        float d2 = dot(l, l) + 0.1;
        l /= sqrt(d2);
        col += shadePBR(n, v, l, albedo, rough, 0.0) * srgbToLinear(strip_color) * strip_glow * stripAt(p.z, sgn, t) * 0.5 / d2;
    }
    // a little bounce light so nothing is pitch black
    col += albedo * (0.012 + 0.03 * shaft_light) * (0.6 + 0.4 * n.y);
    return col;
}

// Haze, the shafts in it (marched) and the glow of the beat lights.
vec3 haze(vec3 col, vec3 ro, vec3 rd, float tl, float t, int samples, vec2 fragCoord) {
    float dens = fog * 0.08;
    float trans = exp(-dens * tl);
    vec3 fogCol = srgbToLinear(shaft_color) * shaft_light * 0.004 + srgbToLinear(strip_color) * strip_glow * 0.003;
    col = col * trans + fogCol * (1.0 - trans);
    // shafts: march through the haze, dust drifting through the light
    float L = min(tl, 30.0);
    float dt = L / float(samples);
    float jit = interleavedGradientNoise(fragCoord + float(iFrame % 16) * 5.588);
    vec3 sc = vec3(0.0);
    float ph = phaseHG(dot(rd, sunDir()), 0.55);
    for (int i = 0; i < 64; i++) {
        if (i >= samples) break;
        float s = (float(i) + jit) * dt;
        vec3 p = ro + rd * s;
        float vis = shaftVis(p);
        if (vis > 0.0) {
            float d = 0.4 + 0.6 * pnoise(vec3(p.x * 1.25, p.y * 1.25 + t * 0.15, p.z * 1.25), vec2(64.0, LOOP * 1.25));
            d = mix(1.0, d, min(dust, 1.0)) * (1.0 + max(dust - 1.0, 0.0) * d);
            sc += vis * d * exp(-dens * s) * dt;
        }
    }
    col += sc * srgbToLinear(shaft_color) * shaft_light * ph * (0.1 + fog * 0.9);
    for (int i = 0; i < 3; i++) {
        vec3 lc; float inten;
        vec3 lp = beatLightPos(i, t, lc, inten);
        col += lc * inten * (0.01 + fog * 0.08) * inscatter(ro, rd, lp, tl);
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float t = iTime * speed;
    vec3 ro, rd;
    float zc;
    tunnelCamera(fragCoord, t, Y_SCALE, vec2(0.0, -0.35), ro, rd, zc);
    int steps = quality >= 3 ? 140 : (quality == 2 ? 100 : 72);
    int haze_samples = quality >= 3 ? 40 : (quality == 2 ? 24 : 14);
    float tmax = 70.0;
    vec3 h = march(ro, rd, tmax, steps);
    float tl = h.x < 0.0 ? tmax : h.x;
    vec3 col = vec3(0.0);
    vec3 p = ro + rd * tl;
    vec2 cp = centre(p.z);
    if (h.x > 0.0 && p.y - cp.y > CEIL_Y + 3.0) {
        // up through a slot: the sky
        col = srgbToLinear(shaft_color) * shaft_light * 2.5;
    } else if (h.x > 0.0) {
        vec3 n = calcNormal(p, 0.0005 * h.x + 0.0008);
        vec3 v = -rd;
        vec3 albedo, emit;
        float rough, wet;
        material(p, n, h.y, t, albedo, rough, emit, wet);
        float ao = quality >= 2 ? calcAO(p, n, 0.4) : clamp(0.35 + 1.6 * map(p + n * 0.3).x, 0.0, 1.0);
        col = directLight(p, n, v, albedo, rough, t, quality >= 3 ? 1.0 : 0.0) * mix(0.4, 1.0, ao) + emit;
        if (h.y == 2.0 && wet > 0.01) {
            // a puddle: a mirror of the tunnel, a little rippled
            vec3 nr = normalize(n + 0.005 * vec3(sin(p.x * 23.0 + t * 2.0), 0.0, sin(p.z * loopFreq(19.0) - t * 2.3)));
            vec3 rdr = reflect(rd, nr);
            vec3 rh = march(p + n * 0.01, rdr, 40.0, quality >= 2 ? 72 : 40);
            float rl = rh.x < 0.0 ? 40.0 : rh.x;
            vec3 refl = vec3(0.0);
            vec3 rp = p + n * 0.01 + rdr * rl;
            vec2 rc = centre(rp.z);
            if (rh.x > 0.0 && rp.y - rc.y > CEIL_Y + 3.0) {
                refl = srgbToLinear(shaft_color) * shaft_light * 2.5;
            } else if (rh.x > 0.0) {
                vec3 rn = calcNormal(rp, 0.002 + 0.001 * rh.x);
                vec3 ra, re;
                float rr, rw;
                material(rp, rn, rh.y, t, ra, rr, re, rw);
                refl = directLight(rp, rn, -rdr, ra, rr, t, 0.0) + re;
            }
            refl = haze(refl, p, rdr, rl, t, max(haze_samples / 2, 6), fragCoord);
            float F = fresnelSchlick(max(dot(nr, -rd), 0.0), vec3(0.02)).x;
            col = mix(col, refl, wet * (0.25 + 0.75 * F) * 0.95 + wet * 0.0);
        }
        if (debug_view == 1) col = n * 0.5 + 0.5;
        if (debug_view == 4) col = vec3(fract(h.y * 0.31), fract(h.y * 0.57), fract(h.y * 0.73));
    }
    col = haze(col, ro, rd, tl, t, haze_samples, fragCoord);
    if (debug_view == 2) col = vec3(h.z / float(steps));
    if (debug_view == 3) col = vec3(1.0 - tl / tmax);
    if (debug_view > 0) { fragColor = vec4(col, 1.0); return; }
    fragColor = vec4(tunnelOutput(col, fragCoord), 1.0);
}
