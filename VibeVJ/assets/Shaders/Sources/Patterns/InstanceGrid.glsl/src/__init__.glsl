//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
const float PI  = 3.14159265358979;
const float TAU = 6.28318530717959;
// Squared length.
float dot2(vec2 v) { return dot(v, v); }
float dot2(vec3 v) { return dot(v, v); }
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

// ---- shader-skills library: sdf2d ----
// Circle of radius r.
float sdCircle(vec2 p, float r) { return length(p) - r; }
// Axis-aligned rectangle with half-extents b.
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
// Equilateral triangle with circumradius-like size r, pointing up.
float sdEquilateralTriangle(vec2 p, float r) {
    const float k = 1.7320508;
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}
// Regular n-gon with circumradius r, one vertex pointing up.
float sdRegularPolygon(vec2 p, float r, int n) {
    float an = PI / float(n);
    vec2 acs = vec2(cos(an), sin(an));
    float len = length(p);
    if (len < 1e-12) return -r * acs.x;
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = len * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p.y += clamp(-p.y, 0.0, r * acs.y);
    return length(p) * sign(p.x);
}
// Star with n points and outer radius r. m in [2, n] sets the inner angle: m = 2 is the spikiest and m = n is a regular n-gon.
float sdStar(vec2 p, float r, int n, float m) {
    float an = PI / float(n);
    float en = PI / m;
    vec2 acs = vec2(cos(an), sin(an));
    vec2 ecs = vec2(cos(en), sin(en));
    float len = length(p);
    if (len < 1e-12) return -r * acs.x;
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = len * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}
// Heart with its bottom tip at the origin, about 1 unit tall.
float sdHeart(vec2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) return sqrt(dot2(p - vec2(0.25, 0.75))) - 0.35355339;
    return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

// ---- shader-skills library: color ----
// Cosine palette a + b * cos(2 pi (c t + d)). Output is display-like (sRGB-ish), so decode it for albedo. Integer c values loop seamlessly over t in [0,1].
vec3 cosinePalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(TAU * (c * t + d));
}

// ---- shader ----
// --- InstanceGrid: one shape copied over a grid, each copy driven by a field (instancing as in TouchDesigner) ---
// The field gives every copy a value from 0 to 1: a wave from the middle, a wave across, noise, a chase on the beat,
// random flicker or a spiral. That value sets the size between Size min and Size max, the extra turn (Field rotate)
// and the colour between Colour A and Colour B. Every copy is drawn with its neighbours, so big or turned shapes
// overlap the next cell instead of being cut off.
// iTime counts beats in Sync: Field speed is in waves per beat, Beat pulse makes all copies jump at every beat.

//@int min=1 max=48 value=12
uniform int columns;
//@int min=1 max=32 value=7
uniform int rows;
//@enum options=(Circle, Square, Triangle, Hexagon, Star, Ring, Cross, Line, Heart) value=1
uniform int shape;
//@enum options=(Radial wave, Linear wave, Noise, Beat chase, Random flicker, Spiral) value=0
uniform int field;
//@slider min=0.1 max=4.0 value=1.0
uniform float field_scale;          // how many waves fit across the grid
//@slider min=-2.0 max=2.0 value=0.25
uniform float field_speed;          // waves per beat
//@slider min=0.0 max=360.0 value=0.0
uniform float field_angle;          // Linear wave: the direction, in degrees
//@slider min=0.0 max=1.5 value=0.2
uniform float size_min;             // size of a copy at field 0, 1 = the cell
//@slider min=0.0 max=1.5 value=0.8
uniform float size_max;             // size at field 1
//@slider min=0.0 max=360.0 value=0.0
uniform float rotate;               // turn of every copy, in degrees
//@slider min=-360.0 max=360.0 value=90.0
uniform float field_rotate;         // extra turn at field 1, in degrees
//@slider min=0.0 max=0.5 value=0.0
uniform float jitter;               // random offset of every copy from its cell
//@slider min=0.0 max=0.3 value=0.0
uniform float outline;              // 0 = filled shapes, else the width of the line
//@slider min=0.0 max=1.0 value=0.3
uniform float glow;
//@slider min=0.0 max=1.0 value=0.3
uniform float beat_pulse;
//@enum options=(Field, Rainbow, Checker, Single) value=0
uniform int color_mode;
//@rgb value=(0.1, 0.35, 1.0)
uniform vec3 color_a;               // the colour at field 0
//@rgb value=(1.0, 0.25, 0.6)
uniform vec3 color_b;               // the colour at field 1
//@rgb value=(0.01, 0.0, 0.03)
uniform vec3 background;

float shapeDist(vec2 p, float r) {
    if (shape == 0) return sdCircle(p, r);
    if (shape == 1) return sdBox(p, vec2(r * 0.85));
    if (shape == 2) return sdEquilateralTriangle(p, r);
    if (shape == 3) return sdRegularPolygon(p, r, 6);
    if (shape == 4) return sdStar(p, r, 5, 2.5);
    if (shape == 5) return abs(sdCircle(p, r * 0.8)) - r * 0.2;
    if (shape == 6) return min(sdBox(p, vec2(r, r * 0.25)), sdBox(p, vec2(r * 0.25, r)));
    if (shape == 7) return sdBox(p, vec2(r, r * 0.12));
    return sdHeart(p / (r * 1.6) + vec2(0.0, 0.5)) * r * 1.6;
}

// The field value of a cell, 0 .. 1. c is the cell centre in grid units with the middle at 0
float fieldAt(vec2 c, vec2 id, vec2 grid) {
    float t = iTime * field_speed;
    float span = max(grid.x, grid.y);
    if (field == 1) {
        float a = radians(field_angle);
        return 0.5 + 0.5 * sin(TAU * (dot(c, vec2(cos(a), sin(a))) / span * field_scale - t));
    }
    if (field == 2)
        return clamp(0.5 + 0.5 * fbm(vec3(c / span * field_scale * 3.0, t), 3, 2.01, 0.5) * 1.6, 0.0, 1.0);
    if (field == 3) {
        // One copy after the other along the rows, one step per beat times the speed
        float n = grid.x * grid.y;
        float idx = id.y * grid.x + id.x;
        float head = mod(floor(iTime * max(abs(field_speed), 0.01) * 4.0), n);
        float back = mod(head - idx + n, n);
        return exp(-back * 0.6 / field_scale);
    }
    if (field == 4) {
        float step_ = floor(iTime * max(abs(field_speed), 0.01) * 8.0);
        return hash13(vec3(id, step_));
    }
    if (field == 5) {
        float ang = atan(c.y, c.x + 1e-6) / TAU;
        return 0.5 + 0.5 * sin(TAU * (ang + length(c) / span * field_scale * 2.0 - t));
    }
    return 0.5 + 0.5 * sin(TAU * (length(c) / span * field_scale * 2.0 - t));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 grid = vec2(float(max(columns, 1)), float(max(rows, 1)));
    // Square cells, the grid fitted into the picture and centred
    float cell = min(iResolution.x / grid.x, iResolution.y / grid.y);
    vec2 g = (fragCoord - 0.5 * iResolution.xy) / cell + 0.5 * grid;
    vec2 base = floor(g);
    float px = 1.0 / cell;
    float pulse = beat_pulse * pow(1.0 - fract(iTime), 3.0);

    vec3 col = background;
    vec3 glowCol = vec3(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 id = base + vec2(float(i), float(j));
            if (id.x < 0.0 || id.y < 0.0 || id.x >= grid.x || id.y >= grid.y)
                continue;
            vec2 rnd = hash22(id + 17.0);
            vec2 centre = id + 0.5 + (rnd - 0.5) * jitter;
            float f = fieldAt(id + 0.5 - 0.5 * grid, id, grid);

            float r = 0.5 * mix(size_min, size_max, f) * (1.0 + pulse);
            vec2 p = rot2(-radians(rotate + field_rotate * f)) * (g - centre);
            float d = shapeDist(p, r);
            if (outline > 0.0)
                d = abs(d) - outline * 0.5;

            vec3 c;
            if (color_mode == 1) c = cosinePalette(f + hash12(id) * 0.2, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
            else if (color_mode == 2) c = mod(id.x + id.y, 2.0) < 0.5 ? color_a : color_b;
            else if (color_mode == 3) c = color_a;
            else c = mix(color_a, color_b, f);

            float fill = 1.0 - smoothstep(-px, px, d);
            col = mix(col, c, fill);
            float gl = exp(-max(d, 0.0) * 8.0) * glow * (0.4 + 0.6 * f);
            glowCol += c * gl;
        }
    }
    col += glowCol * 0.35;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
