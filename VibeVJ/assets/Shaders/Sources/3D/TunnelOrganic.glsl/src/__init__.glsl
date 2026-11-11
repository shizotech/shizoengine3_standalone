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

// ---- shader-skills library: operators ----
// Smooth union (polynomial, C1). Blends where |a - b| < k, with a max bulge of k/4.
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
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
// Thickness behind a surface point, estimated by sampling the SDF inside along -n (an "inverse AO"). Returns 0 (thin, light passes through) .. 1 (thick). maxDepth is the deepest sample in scene units.
float sdfThickness(vec3 p, vec3 n, float maxDepth) {
    float acc = 0.0;
    for (int i = ZERO; i < 4; i++) {
        float h = maxDepth * (float(i) + 1.0) / 4.0;
        acc += clamp(-map(p - n * h).x / h, 0.0, 1.0);
    }
    return acc / 4.0;
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
// Fast translucency (Barre-Brisebois and Bouchard 2011): light passing through thin parts, seen from the back. distortion bends the light along the normal (0.2-0.5). thickness is 0 (thin) .. 1 (thick); see sdfThickness.
float translucency(vec3 n, vec3 v, vec3 l, float distortion, float power, float thickness) {
    vec3 h = normalize(l + n * distortion);
    return pow(clamp(dot(v, -h), 0.0, 1.0), power) * (1.0 - thickness);
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
// TunnelOrganic: a flight through a raymarched biomechanical tunnel: ribs like vertebrae, tendons that twist along
// the walls and melt into them, a dark wet skin with glossy highlights, and light that shines through it from the
// glowing veins underneath (subsurface). The tunnel beats like a heart on every beat, pulses run along the veins,
// lights race past. Time counts beats in Sync.

//@slider min=1.2 max=4.0 value=2.0
uniform float tube_radius;    // metres
//@slider min=0.6 max=4.0 value=1.4
uniform float rib_spacing;    // metres between the ribs
//@slider min=0.0 max=0.5 value=0.3
uniform float rib_size;       // thickness of the ribs
//@int min=0 max=10 value=6
uniform int tendons;          // tendons along the walls
//@slider min=-1.0 max=1.0 value=0.25
uniform float twist;          // turns of the tendons per 8 metres
//@slider min=0.0 max=1.0 value=0.5
uniform float heartbeat;      // the tunnel swells on every beat (two beats, like a heart)
//@rgb value=(0.07, 0.075, 0.08)
uniform vec3 skin_color;      // the dark skin
//@rgb value=(0.75, 0.10, 0.06)
uniform vec3 flesh_color;     // the colour of the light inside the skin (subsurface)
//@slider min=0.0 max=1.0 value=0.7
uniform float gloss;          // wet shine of the skin
//@rgb value=(1.0, 0.38, 0.10)
uniform vec3 vein_color;
//@slider min=0.0 max=4.0 value=0.8
uniform float vein_glow;
//@slider min=0.0 max=4.0 value=1.0
uniform float vein_pulse;     // pulses per beat running along the veins
//@rgb value=(0.95, 0.9, 1.0)
uniform vec3 light_color;     // the beat lights
//@rgb value=(0.4, 1.0, 0.7)
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

// Heartbeat 0..1: two pulses per beat, "lub-dub".
float heart(float t) {
    float f = fract(t);
    return exp(-14.0 * f) + 0.6 * exp(-14.0 * max(f - 0.22, 0.0)) * step(0.22, f);
}

vec2 map(vec3 p) {
    vec2 q = p.xy - tunnelPath(p.z);
    float r = length(q);
    float a = atan(q.y, q.x);
    float t = iTime * speed;
    float R = tube_radius * (1.0 - 0.05 * heartbeat * heart(t));
    // the skin: slow bulges
    float bump = 0.06 * sin(a * 5.0 + p.z * TAU / 8.0) * sin(p.z * TAU / 3.2 - a * 2.0);
    float wall = R + bump - r;
    float d = wall;
    float mat = 1.0;
    // ribs: rings that melt into the wall
    if (rib_size > 0.0) {
        float rs = loopFit(rib_spacing, 1.0);
        float zf = mod(p.z, rs) - 0.5 * rs;
        float rr = R - 0.06 + 0.04 * sin(a * 9.0);
        float rib = length(vec2((r - rr) * 0.6, zf)) - rib_size * (0.75 + 0.25 * cos(a * 3.0));
        float k = smin(d, rib, 0.25);
        if (rib < d) mat = 2.0;
        d = k;
    }
    // tendons twisting along the wall
    if (tendons > 0) {
        float n = float(tendons);
        float sec = TAU / n;
        float aa = a - floor(twist * LOOP / 8.0 + 0.5) * TAU * p.z / LOOP;   // whole turns per loop
        float id = floor(aa / sec + 0.5);
        float da = (aa - id * sec) * (R - 0.12);
        float ten = length(vec2(da, r - (R - 0.12))) - 0.1 - 0.03 * sin(p.z * loopFreq(3.0) + mod(id, n) * 2.0);
        float k = smin(d, ten, 0.18);
        if (ten < d) mat = 3.0;
        d = k;
    }
    return vec2(d * 0.85, mat);
}

vec3 march(vec3 ro, vec3 rd, float tmax, int steps) {
    float t = 0.02;
    for (int i = ZERO; i < 200; i++) {
        if (i >= steps) break;
        vec2 h = map(ro + rd * t);
        if (abs(h.x) < 0.0006 * t + 0.0005) return vec3(t, h.y, float(i));
        t += h.x;
        if (t > tmax) break;
    }
    return vec3(-1.0, 0.0, float(steps));
}

// Distance to the nearest vein: the borders of cells on the wall, closed around the tunnel and along the loop.
// Returns vec2(border distance, cell hash).
vec2 veins(vec2 uv, vec2 period) {
    vec2 ip = floor(uv);
    vec2 fp = uv - ip;
    float d1 = 8.0, d2 = 8.0;
    float hid = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 o = vec2(float(i), float(j));
            vec2 c = mod(ip + o, period);
            vec2 pt = o + 0.15 + 0.7 * hash22(c) - fp;
            float d = dot(pt, pt);
            if (d < d1) { d2 = d1; d1 = d; hid = hash12(c + 3.0); }
            else if (d < d2) d2 = d;
        }
    }
    return vec2(sqrt(d2) - sqrt(d1), hid);
}

void skin(vec3 p, vec3 n, float mat, float t, out vec3 albedo, out float rough, out vec3 glow) {
    vec2 q = p.xy - tunnelPath(p.z);
    float a = atan(q.y, q.x);
    float u = (a / TAU + 0.5);
    // two scales of veins; the big ones carry the pulses
    vec2 vb = veins(vec2(u * 11.0, p.z * 0.75), vec2(11.0, LOOP * 0.75));
    vec2 vs = veins(vec2(u * 48.0, p.z * 3.25), vec2(48.0, LOOP * 3.25));
    float big = 1.0 - smoothstep(0.0, 0.09, vb.x);
    float small = 1.0 - smoothstep(0.0, 0.06, vs.x);
    float near = exp(-vb.x * 9.0);                    // light spreading under the skin around a vein
    float pulse = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * (p.z * 40.0 / LOOP - vein_pulse * t) + vb.y * 6.0), 6.0);
    pulse *= 1.0 + 1.5 * heart(t) * heartbeat;
    float tex = pnoise(vec3(u * 96.0, 0.0, p.z * 6.0), vec2(96.0, LOOP * 6.0));
    albedo = srgbToLinear(skin_color) * (0.7 + 0.6 * tex);
    albedo = mix(albedo, srgbToLinear(flesh_color) * 0.25, 0.5 * near);
    rough = mix(0.55, 0.12, gloss) + 0.15 * tex;
    if (mat == 2.0) { albedo *= 1.25; rough *= 0.8; }
    if (mat == 3.0) { albedo *= 0.8; rough *= 0.7; }
    vec3 vc = srgbToLinear(vein_color);
    glow = vc * vein_glow * (big * 1.3 + small * 0.12) * pulse
         + srgbToLinear(flesh_color) * vein_glow * near * 0.5 * pulse;
}

vec3 directLight(vec3 p, vec3 n, vec3 v, vec3 albedo, float rough, float t, vec3 camPos) {
    vec3 col = vec3(0.0);
    float zc = flightZ(t);
    for (int i = 0; i < 3; i++) {
        vec2 bl = beatLight(i, t, zc);
        vec3 lp = vec3(tunnelPath(bl.x), bl.x);
        vec3 l = lp - p;
        float d2 = dot(l, l);
        l /= sqrt(d2);
        vec3 lc = mod(floor(t) - float(i), 2.0) < 0.5 ? srgbToLinear(light_color) : srgbToLinear(light_color_b);
        col += shadePBR(n, v, l, albedo, rough, 0.0) * lc * bl.y * 9.0 / (1.0 + d2);
        // light that goes through the thin skin: a red glow on the side away from the light
        col += srgbToLinear(flesh_color) * translucency(n, v, l, 0.3, 3.0, 1.0) * lc * bl.y * 2.0 / (1.0 + d2);
    }
    vec3 lh = normalize(camPos - p);
    col += shadePBR(n, v, lh, albedo, rough, 0.0) * vec3(1.0, 0.95, 0.9) * 0.35 / (1.0 + dot(camPos - p, camPos - p) * 0.25);
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float t = iTime * speed;
    vec3 ro, rd;
    float zc;
    tunnelCamera(fragCoord, t, 1.0, vec2(0.0), ro, rd, zc);
    int steps = quality >= 3 ? 150 : (quality == 2 ? 110 : 80);
    float tmax = 50.0;
    vec3 h = march(ro, rd, tmax, steps);
    float tl = h.x < 0.0 ? tmax : h.x;
    vec3 col = vec3(0.0);
    if (h.x > 0.0) {
        vec3 p = ro + rd * h.x;
        vec3 n = calcNormal(p, 0.0006 * h.x + 0.001);
        vec3 v = -rd;
        vec3 albedo, glow;
        float rough;
        skin(p, n, h.y, t, albedo, rough, glow);
        float ao = quality >= 2 ? calcAO(p, n, 0.3) : clamp(0.35 + 2.0 * map(p + n * 0.22).x, 0.0, 1.0);
        col = directLight(p, n, v, albedo, rough, t, ro) * ao;
        // the veins shine through the skin: softer where it is thick (the crevices), a rim on thin edges
        float thin = quality >= 2 ? 1.0 - clamp(sdfThickness(p, n, 0.25), 0.0, 1.0) : 0.5;
        col += glow * mix(0.35, 1.0, ao) * (0.6 + 0.6 * thin);
        // wet shine: the glow of the beat lights and of the veins mirrored in the skin
        vec3 f0 = vec3(0.03);
        vec3 spec = envBRDFApprox(f0, max(dot(n, v), 0.0), rough);
        vec3 rdr = reflect(rd, n);
        vec3 refl = vec3(0.0);
        if (quality >= 2) {
            vec3 rh = march(p + n * 0.02, rdr, 12.0, 48);
            if (rh.x > 0.0) {
                vec3 rp = p + n * 0.02 + rdr * rh.x;
                vec3 rn = calcNormal(rp, 0.003);
                vec3 ra, rg;
                float rr;
                skin(rp, rn, rh.y, t, ra, rr, rg);
                refl = rg * 0.8 + directLight(rp, rn, -rdr, ra, rr, t, ro);
            }
        } else {
            refl = srgbToLinear(vein_color) * vein_glow * 0.12;
        }
        for (int i = 0; i < 3; i++) {
            vec2 bl = beatLight(i, t, zc);
            vec3 lc = mod(floor(t) - float(i), 2.0) < 0.5 ? srgbToLinear(light_color) : srgbToLinear(light_color_b);
            refl += lc * bl.y * 0.25 * inscatter(p, rdr, vec3(tunnelPath(bl.x), bl.x), 12.0);
        }
        col += spec * refl * gloss * 2.0;
        if (debug_view == 1) col = n * 0.5 + 0.5;
        if (debug_view == 4) col = vec3(fract(h.y * 0.31), fract(h.y * 0.57), fract(h.y * 0.73));
    }
    // dark red haze, the beat lights glowing in it
    float trans = exp(-fog * 0.1 * tl);
    vec3 fogCol = srgbToLinear(flesh_color) * vein_glow * 0.02;
    col = col * trans + fogCol * (1.0 - trans);
    for (int i = 0; i < 3; i++) {
        vec2 bl = beatLight(i, t, zc);
        vec3 lc = mod(floor(t) - float(i), 2.0) < 0.5 ? srgbToLinear(light_color) : srgbToLinear(light_color_b);
        col += lc * bl.y * (0.004 + fog * 0.05) * inscatter(ro, rd, vec3(tunnelPath(bl.x), bl.x), tl);
    }
    if (debug_view == 2) col = vec3(h.z / float(steps));
    if (debug_view == 3) col = vec3(1.0 - tl / tmax);
    if (debug_view > 0) { fragColor = vec4(col, 1.0); return; }
    fragColor = vec4(tunnelOutput(col, fragCoord), 1.0);
}
