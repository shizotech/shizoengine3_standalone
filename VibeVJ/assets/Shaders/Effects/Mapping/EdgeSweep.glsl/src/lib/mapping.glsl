// ---- Projection mapping building blocks (#586): the code every asset of the set shares ----
// The same file is in src/lib/ of each of them (an asset folder can only include its own files). The controls of the
// mask have the same names in every asset, so a preset, a link or a MIDI mapping means the same everywhere.
// A pass sets PASS_SCALE to its renderscale before it includes this file (1.0 for a full-size pass).
#ifndef PASS_SCALE
#define PASS_SCALE 1.0
#endif
// What "Auto" means when no picture is linked into the port Mask: 2 the demo facade, 3 the demo objects, 4 none
#ifndef MASK_AUTO
#define MASK_AUTO 2
#endif

const float MP_PI = 3.14159265358979;
const float MP_TAU = 6.28318530717959;

// ---- random numbers: PCG hash, no sine hash ----
uint mp_hash(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}
float mp_rand(uint v) { return float(mp_hash(v) >> 8u) * (1.0 / 16777216.0); }
float mp_rand2(ivec2 p) { return mp_rand(uint(p.x + 32768) + mp_hash(uint(p.y + 32768) * 7919u)); }
float mp_rand3(ivec3 p) { return mp_rand(uint(p.x + 32768) + mp_hash(uint(p.y + 32768) * 7919u + mp_hash(uint(p.z + 32768)))); }

float mp_vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    ivec2 c = ivec2(i);
    float a = mp_rand2(c);
    float b = mp_rand2(c + ivec2(1, 0));
    float d = mp_rand2(c + ivec2(0, 1));
    float e = mp_rand2(c + ivec2(1, 1));
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

vec3 mp_hue(float h) {
    return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

mat2 mp_rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, s, -s, c);
}

// One pass pixel in pixels of the full picture
float mp_full_px() { return 1.0 / PASS_SCALE; }

// Bilinear read with texelFetch: the textures of passes are nearest, so a pass that reads a smaller one gets blocks.
// pos is in texels of tex (0.5 = the middle of the first texel).
vec4 mp_bilinear(sampler2D tex, vec2 pos) {
    ivec2 size = textureSize(tex, 0);
    vec2 p = pos - 0.5;
    vec2 f = fract(p);
    ivec2 i = ivec2(floor(p));
    ivec2 hi = max(size - 1, ivec2(0));
    vec4 a = texelFetch(tex, clamp(i, ivec2(0), hi), 0);
    vec4 b = texelFetch(tex, clamp(i + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(tex, clamp(i + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(tex, clamp(i + ivec2(1, 1), ivec2(0), hi), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
vec4 mp_bilinear_uv(sampler2D tex, vec2 uv) { return mp_bilinear(tex, uv * vec2(textureSize(tex, 0))); }

// The beat and the trigger, read from the pass T (lib/beat.glsl): x the pulse envelope (1 at a pulse, then falls
// frame by frame), y the number of pulses so far, z 1 in the frame of a pulse
vec3 mp_pulse(sampler2D T) {
    vec4 t = texelFetch(T, ivec2(0, 0), 0);
    return vec3(t.g, t.b, t.a);
}

// ---- 2D distances for the demo shapes ----
float mp_sd_box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float mp_sd_tri(vec2 p, float r) {
    const float k = 1.7320508;
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}
