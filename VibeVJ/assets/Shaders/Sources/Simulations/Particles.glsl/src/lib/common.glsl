// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
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
// 4D integer hash, four decorrelated outputs (0 BigCrush failures in the JCGT study).
uvec4 pcg4d(uvec4 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    v ^= v >> 16u;
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
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
// Random vec3 in [0,1)^3 for an integer-valued 3D input.
vec3 hash33(vec3 p) { return uintToUnit(pcg3d(uvec3(ivec3(floor(p))))); }
// Random vec4 in [0,1)^4 for an integer-valued 4D input.
vec4 hash44(vec4 p) { return uintToUnit(pcg4d(uvec4(ivec4(floor(p))))); }

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
// Divergence-free 2D flow field: the curl of scalar gradient noise. Particles advected by it swirl without bunching up.
vec2 curlNoise(vec2 p) {
    vec3 n = gradientNoiseD(p);
    return vec2(n.z, -n.y);
}
// Divergence-free 3D flow field: the curl of a vector potential whose components are three decorrelated gradientNoiseD fields. Analytic, so it costs three noise evaluations and no finite differences.
vec3 curlNoise(vec3 p) {
    vec3 a = gradientNoiseD(p).yzw;                                   // grad of potential.x
    vec3 b = gradientNoiseD(p + vec3(31.416, -47.853, 12.793)).yzw;   // grad of potential.y
    vec3 c = gradientNoiseD(p + vec3(-23.719, 18.274, -56.183)).yzw;  // grad of potential.z
    return vec3(c.y - b.z, a.z - c.x, b.x - a.y);
}

// ---- shader-skills library: color ----
// Relative luminance of linear Rec.709 / sRGB color.
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// ---- shader ----
// --- Particles: what both passes share ---
// GPU particles without a draw call: pass P is a grid of cells (a quarter of the picture size: one cell is 4 x 4
// pixels, 129 600 cells at 1080p) and each cell holds at most one particle. Every frame a cell looks at the 5 x 5
// cells around it and takes over the particle that moves into it (the oldest one when two do; the other is lost),
// or, when it stays empty, may give birth to a new one. So the particles live in a float texture, move up to 2 cells
// a frame and cost the same however many there are. A cell stores where its particle will be in the next frame,
// so the forces are worked out once per particle. __init__ draws the particles of the cells around each pixel as
// soft dots with a streak along their motion. T keeps the beat (a new beat starts, its envelope).
//
// A cell: r, g = the next position (in cells), b = the velocity (two 12-bit numbers), a = age in frames x 4096 +
// a 12-bit random seed, or -1 for an empty cell. Whole numbers below 2^24 are exact in a 32-bit float.
// The simulation counts frames: at 30 fps everything moves half as fast as at 60 fps.

//@enum options=(Everywhere, Point, Ring, Fountain, Field picture) value=1
uniform int emitter;                // where new particles are born; Field picture: where the port Field is bright
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 emitter_position;      // Point, Ring, Fountain; also the center of Attract, Orbit and the beat kick
//@slider min=0.0 max=0.5 value=0.08
uniform float emitter_size;
//@slider min=0.0 max=1.0 value=0.3
uniform float emit_rate;            // the chance of an empty cell in the emitter to get a particle each frame
//@slider min=0.0 max=2.0 value=0.4
uniform float start_speed;          // cells per frame
//@slider min=0.0 max=1.0 value=0.5
uniform float spread;               // randomness of the start direction and speed
//@slider min=0.2 max=20.0 value=4.0
uniform float lifetime;             // seconds (each particle lives 0.6 to 1.4 times this)
//@slider min=0.0 max=2.0 value=0.6
uniform float flow_strength;        // a swirling curl-noise wind
//@slider min=0.5 max=12.0 value=3.0
uniform float flow_scale;
//@slider min=0.0 max=2.0 value=0.2
uniform float flow_speed;           // how fast the wind changes, per beat
//@slidervec2 min=(-1.0,-1.0) max=(1.0,1.0) value=(0.0,0.0)
uniform vec2 gravity;
//@slider min=-2.0 max=2.0 value=0.0
uniform float attract;              // > 0 pulls towards the emitter position, < 0 pushes away
//@slider min=-2.0 max=2.0 value=0.0
uniform float orbit;                // turns the particles around the emitter position
//@slider min=0.0 max=0.2 value=0.02
uniform float drag;
//@enum options=(Wrap, Kill) value=1
uniform int edge_mode;              // what happens at the border
//@slider min=-4.0 max=4.0 value=0.0
uniform float field_push;           // pushes along the slopes of the brightness of the port Field (uphill if > 0)
//@slider min=0.0 max=1.0 value=0.5
uniform float beat_burst;           // at every beat the emitter fires: the chance of a birth there
//@slider min=0.0 max=3.0 value=1.2
uniform float burst_speed;          // cells per frame, away from the emitter
//@slider min=0.0 max=2.0 value=0.0
uniform float beat_kick;            // at every beat all particles get a push away from the emitter position
//@button
uniform bool reset;                 // empties the grid while it is on

// A picture for the emitter Field picture, Field push and Color mode From field
uniform sampler2D field;

const float VMAX = 2.0;

struct Particle {
    vec2 pos;       // the next position, in cells
    vec2 vel;       // cells per frame
    float age;      // frames
    float seed;     // 0 .. 4095
    bool alive;
};

Particle decodeCell(vec4 s) {
    Particle p;
    p.alive = s.a >= 0.0;
    p.pos = s.rg;
    float q = s.b;
    float qy = floor(q / 4096.0);
    float qx = q - qy * 4096.0;
    p.vel = (vec2(qx, qy) / 4095.0 * 2.0 - 1.0) * VMAX;
    p.age = floor(s.a / 4096.0);
    p.seed = s.a - p.age * 4096.0;
    return p;
}

vec4 encodeCell(Particle p) {
    if (!p.alive)
        return vec4(0.0, 0.0, 0.0, -1.0);
    vec2 q = floor((clamp(p.vel / VMAX, -1.0, 1.0) * 0.5 + 0.5) * 4095.0 + 0.5);
    return vec4(p.pos, q.x + 4096.0 * q.y, min(p.age, 4095.0) * 4096.0 + p.seed);
}

// Frames a particle with this seed lives
float lifeFrames(float seed) {
    float fps = 1.0 / max(iTimeDelta, 1.0 / 240.0);
    return lifetime * fps * (0.6 + 0.8 * hash11(seed + 17.0));
}
