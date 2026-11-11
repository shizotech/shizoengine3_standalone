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

// ---- shader-skills library: sdf2d ----
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
// Vesica (lens): intersection of two circles of radius r whose centers sit at (+-d, 0). Points along Y. Needs d < r.
float sdVesica(vec2 p, float r, float d) {
    p = abs(p);
    float b = sqrt(r * r - d * d);
    return ((p.y - b) * d > p.x * b) ? length(p - vec2(0.0, b))
                                     : length(p - vec2(-d, 0.0)) - r;
}
// Rhombus with half-diagonals b.
float sdRhombus(vec2 p, vec2 b) {
    p = abs(p);
    vec2 t = b - 2.0 * p;
    float h = clamp((t.x * b.x - t.y * b.y) / dot(b, b), -1.0, 1.0);
    float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
    return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}

// ---- shader-skills library: domain ----
// Polar repetition into n sectors around the origin. Returns the point rotated into the sector centered on +X. Single evaluation: exact for shapes symmetric about their sector's center line. For asymmetric or per-sector-varying shapes, evaluate this sector and its neighbor and take the min (see references/sdf-library-guide.md).
vec2 domPolar(vec2 p, float n) {
    if (dot(p, p) < 1e-20) return p;
    float sector = TAU / n;
    float id = floor(atan(p.y, p.x) / sector + 0.5);
    return rot2(-id * sector) * p;
}

// ---- shader ----
// CarpetPersian: a Persian medallion carpet for big LED walls: a medallion with pendants, corner pieces, a field of
// flowers on a lattice of vines, a main border with rosettes and cartouches between two guard bands, the knots and the
// stripes of hand-dyed wool. The medallion breathes and turns, the field drifts, the border motifs run around the
// frame, the medallion changes its shape on the beat. Time counts beats in Sync.

//@enum options=(Whole wall, Repeat carpets, Field only) value=0
uniform int carpet_layout;           // one carpet over all screens, a grid of carpets, or only the flower field
//@slider min=0.3 max=4.0 value=1.0
uniform float carpet_size;    // Repeat carpets: height of one carpet in screen heights
//@slider min=0.4 max=2.5 value=1.4
uniform float carpet_aspect;  // Repeat carpets: width / height of one carpet
//@enum options=(Lobed, Star, Lozenge, Round) value=0
uniform int medallion_shape;
//@enum options=(Lobed, Star, Lozenge, Round) value=1
uniform int medallion_shape_b; // the shape the medallion morphs to and back
//@int min=0 max=64 value=16
uniform int morph_every;      // beats between the morphs; 0 = only the first shape
//@slider min=0.25 max=16.0 value=4.0
uniform float morph_beats;    // how long a morph takes, in beats
//@slider min=0.0 max=0.9 value=0.42
uniform float medallion_size; // radius in carpet half-heights; 0 = no medallion
//@int min=4 max=16 value=8
uniform int medallion_points; // lobes / points of the medallion and petals of its rings
//@slider min=-2.0 max=2.0 value=0.5
uniform float medallion_spin; // turns of the inner rings per 32 beats (the outer shape stays)
//@slider min=0.0 max=1.0 value=0.5
uniform float breathe;        // the medallion grows and shrinks over loop_beats
//@slider min=0.0 max=0.6 value=0.3
uniform float corner_size;    // the quarter medallions in the corners of the field
//@slider min=1.0 max=24.0 value=7.0
uniform float field_density;  // flowers across the height of one screen
//@slider min=0.0 max=0.4 value=0.16
uniform float border_width;   // the main border, in carpet half-heights; 0 = no border
//@slider min=-2.0 max=2.0 value=0.25
uniform float border_run;     // border motifs per beat running around the frame
//@enum options=(Tabriz, Kashan, Heriz, Nain, Qashqai, Neon, Custom colours) value=0
uniform int palette;
//@rgb value=(0.55, 0.09, 0.08)
uniform vec3 field_color;     // Custom colours: the field
//@rgb value=(0.07, 0.10, 0.26)
uniform vec3 border_color;    // Custom colours: the border and the medallion
//@rgb value=(0.88, 0.81, 0.66)
uniform vec3 light_color;     // Custom colours: ivory
//@rgb value=(0.80, 0.58, 0.20)
uniform vec3 accent_color;    // Custom colours: flowers and details
//@slider min=0.0 max=1.0 value=0.5
uniform float knots;          // the knots of the wool: a fine grid of soft dots
//@slider min=1.0 max=16.0 value=3.0
uniform float knot_size;      // size of a knot in LED pixels
//@slider min=0.0 max=1.0 value=0.4
uniform float abrash;         // stripes of slightly different dye across the carpet
//@slider min=0.0 max=1.0 value=0.5
uniform float beat_pulse;     // the medallion and some flowers light up on the beat
//@slider min=0.0 max=1.0 value=0.3
uniform float twinkle;        // share of the flowers that light up
//@int min=0 max=999 value=0
uniform int seed;

// ---- Motion and warp (the same controls in every carpet) ----
//@slider min=0.0 max=4.0 value=1.0
uniform float speed;          // multiplies the time; the time counts beats in Sync
//@slider min=0.0 max=2.0 value=0.25
uniform float scroll_speed;   // tiles per 4 beats
//@slider min=0.0 max=360.0 value=90.0
uniform float scroll_angle;   // direction of the scroll in degrees, 90 = up
//@slider min=0.0 max=360.0 value=0.0
uniform float rotation;       // turns the carpet, degrees
//@slider min=-1.0 max=1.0 value=0.0
uniform float rotate_speed;   // turns per 64 beats
//@enum options=(None, Swirl, Cloth waves, Lens, Flow, Beat ripple) value=0
uniform int warp_mode;
//@slider min=0.0 max=1.0 value=0.5
uniform float warp_amount;
//@slider min=0.2 max=4.0 value=1.0
uniform float warp_scale;     // size of the warp in screen heights
//@int min=1 max=64 value=16
uniform int loop_beats;       // the warp and the breathing repeat after this many beats

// ---- LED wall ----
//@slider min=0.0 max=32.0 value=0.0
uniform float led_pixel;      // size of one LED in output pixels; 0 = off, from 1 on every LED gets one clean colour
//@slider min=0.5 max=4.0 value=1.0
uniform float softness;       // edge filter in LED pixels: higher is softer and shimmers less on coarse walls
//@int min=1 max=8 value=1
uniform int wall_columns;     // screens side by side that show one carpet
//@int min=1 max=8 value=1
uniform int wall_rows;        // screens above each other
//@int min=1 max=8 value=1
uniform int screen_column;    // which of them this output is, 1 = left
//@int min=1 max=8 value=1
uniform int screen_row;       // 1 = top
//@slider min=0.0 max=0.5 value=0.0
uniform float screen_gap;     // gap between the screens in screen heights, so lines run on straight across it
//@slidervec2 min=(-4,-4) max=(4,4) value=(0,0)
uniform vec2 canvas_offset;   // moves the carpet in screen heights (line up several outputs by hand)
//@slider min=0.05 max=1.0 value=0.9
uniform float brightness;     // the brightest white: LED walls are blinding, 0.5 is often plenty
//@slider min=0.5 max=3.0 value=1.0
uniform float led_gamma;      // > 1 darkens the mid tones for walls without a gamma curve
//@slider min=0.0 max=0.25 value=0.0
uniform float black_floor;    // lifts black, against flicker in the lowest LED levels
//@int min=1 max=3 value=1
uniform int quality;          // 1 = one sample per LED; 2 and 3 = 4 and 9 samples, smoother edges

// Width / height of the picture (computed here: iResolution.z was 1 in the app before #586, an integer division).
float screenAspect() { return iResolution.x / max(iResolution.y, 1.0); }

// Output pixels per LED (one LED = one pixel when led_pixel is off).
float ledSize() { return max(led_pixel, 1.0); }

// The pixel this fragment stands for: the centre of its LED when led_pixel is on.
vec2 ledCentre(vec2 fragCoord) {
    if (led_pixel < 1.0) return fragCoord;
    return (floor(fragCoord / led_pixel) + 0.5) * led_pixel;
}

// Output pixel -> wall units: one screen height is 2.0, 0 is the middle of the whole wall, y up. The screens of
// the wall all render the same carpet, each its own part of it, so lines and motion run on across the screens.
vec2 wallPosition(vec2 fc) {
    vec2 res = iResolution.xy;
    vec2 grid = vec2(float(max(wall_columns, 1)), float(max(wall_rows, 1)));
    vec2 cell = vec2(float(clamp(screen_column, 1, max(wall_columns, 1)) - 1),
                     float(max(wall_rows, 1) - clamp(screen_row, 1, max(wall_rows, 1))));
    float gap = screen_gap * res.y;
    vec2 wallRes = grid * res + (grid - 1.0) * gap;
    vec2 px = fc + cell * (res + gap);
    return (2.0 * px - wallRes) / res.y - canvas_offset * 2.0;
}

// Half the size of the whole wall in wall units (the screens and the gaps between them).
vec2 wallHalfSize() {
    vec2 grid = vec2(float(max(wall_columns, 1)), float(max(wall_rows, 1)));
    return grid * vec2(screenAspect(), 1.0) + (grid - 1.0) * screen_gap;
}

// Time in beats times speed.
float carpetTime() { return iTime * speed; }

// Phase 0..1 that repeats every loop_beats (seamless loops of the warp and breathing).
float loopPhase(float t) { return fract(t / float(max(loop_beats, 1))); }

// The warp of the wall position (before the carpet's own scale).
vec2 warpDomain(vec2 p, float t) {
    float a = warp_amount;
    float ph = TAU * loopPhase(t);
    float s = warp_scale;
    if (warp_mode == 1) {
        float r = length(p) / s;
        p = rot2(a * 3.0 * exp(-r * r) * sin(ph)) * p;
    } else if (warp_mode == 2) {
        p += a * 0.12 * s * vec2(sin(p.y * 2.7 / s + ph) + 0.5 * sin(p.x * 1.3 / s - 2.0 * ph),
                                 sin(p.x * 2.1 / s - ph) + 0.5 * sin(p.y * 1.7 / s + ph));
    } else if (warp_mode == 3) {
        vec2 c = vec2(0.9 * sin(ph), 0.45 * sin(2.0 * ph)) * min(screenAspect(), 2.0);
        vec2 d = p - c;
        float r2 = dot(d, d) / (s * s * 0.36);
        p = c + d * (1.0 - a * 0.65 * exp(-r2));
    } else if (warp_mode == 4) {
        vec2 o = 1.3 * vec2(cos(ph), sin(ph));
        vec2 q = p / s;
        p += a * 0.35 * s * vec2(gradientNoise(q + o), gradientNoise(q.yx - o + 7.31));
    } else if (warp_mode == 5) {
        float r = length(p) / s;
        float beat = fract(t);
        float wave = sin(TAU * (r * 2.0 - beat * 2.0)) * exp(-3.0 * abs(r - beat * 1.5)) * (1.0 - beat);
        p += a * 0.1 * s * wave * p / max(length(p), 1e-4);
    }
    return p;
}

// Scroll and turn (applied after the warp, in carpet units).
vec2 moveCarpet(vec2 p, float t, vec2 period) {
    float ang = radians(rotation) + TAU * rotate_speed * t / 64.0;
    p = rot2(-ang) * p;
    float sa = radians(scroll_angle);
    // mod by the period of the pattern (where it repeats itself in x and y) keeps the numbers small after hours
    vec2 off = mod(vec2(cos(sa), sin(sa)) * (scroll_speed * t / 4.0), period);
    return p - off;
}

// The look of a LED wall: gamma, the brightest white, the lifted black (display values in, display values out).
vec3 ledOutput(vec3 c) {
    c = pow(clamp(c, 0.0, 1.0), vec3(led_gamma));
    return mix(vec3(black_floor), vec3(brightness), c);
}

// colours: 0 field, 1 border, 2 medallion, 3 medallion inside, 4 accent, 5 accent 2, 6 dark lines, 7 ivory
vec3 rugColor(int i) {
    vec3 c[8];
    if (palette == 0) {        // Tabriz: madder red field, indigo border and medallion, ivory, gold
        c[0] = vec3(0.56, 0.09, 0.08); c[1] = vec3(0.07, 0.10, 0.27); c[2] = vec3(0.08, 0.13, 0.33);
        c[3] = vec3(0.86, 0.79, 0.62); c[4] = vec3(0.82, 0.60, 0.22); c[5] = vec3(0.16, 0.38, 0.30);
        c[6] = vec3(0.05, 0.04, 0.06); c[7] = vec3(0.92, 0.87, 0.74);
    } else if (palette == 1) { // Kashan: deep blue field, red medallion
        c[0] = vec3(0.06, 0.09, 0.25); c[1] = vec3(0.50, 0.07, 0.08); c[2] = vec3(0.60, 0.10, 0.09);
        c[3] = vec3(0.90, 0.84, 0.70); c[4] = vec3(0.85, 0.66, 0.28); c[5] = vec3(0.30, 0.50, 0.62);
        c[6] = vec3(0.04, 0.04, 0.07); c[7] = vec3(0.93, 0.89, 0.78);
    } else if (palette == 2) { // Heriz: brick, ivory medallion, blue
        c[0] = vec3(0.66, 0.24, 0.13); c[1] = vec3(0.10, 0.16, 0.32); c[2] = vec3(0.88, 0.80, 0.64);
        c[3] = vec3(0.12, 0.22, 0.42); c[4] = vec3(0.40, 0.56, 0.70); c[5] = vec3(0.20, 0.40, 0.30);
        c[6] = vec3(0.08, 0.06, 0.08); c[7] = vec3(0.94, 0.88, 0.74);
    } else if (palette == 3) { // Nain: ivory field, blue design
        c[0] = vec3(0.90, 0.86, 0.76); c[1] = vec3(0.12, 0.22, 0.45); c[2] = vec3(0.20, 0.32, 0.58);
        c[3] = vec3(0.85, 0.80, 0.70); c[4] = vec3(0.30, 0.48, 0.72); c[5] = vec3(0.62, 0.52, 0.36);
        c[6] = vec3(0.10, 0.14, 0.28); c[7] = vec3(0.97, 0.95, 0.88);
    } else if (palette == 4) { // Qashqai: bold tribal red, indigo, saffron, white
        c[0] = vec3(0.62, 0.06, 0.06); c[1] = vec3(0.05, 0.07, 0.20); c[2] = vec3(0.07, 0.11, 0.35);
        c[3] = vec3(0.95, 0.72, 0.12); c[4] = vec3(0.96, 0.94, 0.88); c[5] = vec3(0.15, 0.48, 0.30);
        c[6] = vec3(0.03, 0.02, 0.03); c[7] = vec3(0.96, 0.94, 0.88);
    } else if (palette == 5) { // Neon: lines of light on black
        c[0] = vec3(0.02, 0.01, 0.04); c[1] = vec3(0.05, 0.02, 0.10); c[2] = vec3(0.45, 0.02, 0.50);
        c[3] = vec3(0.02, 0.60, 0.70); c[4] = vec3(1.00, 0.35, 0.05); c[5] = vec3(0.10, 0.90, 0.40);
        c[6] = vec3(0.00); c[7] = vec3(0.10, 0.95, 1.00);
    } else {
        c[0] = field_color; c[1] = border_color; c[2] = border_color * 1.2; c[3] = light_color;
        c[4] = accent_color; c[5] = mix(accent_color, border_color, 0.5); c[6] = border_color * 0.25;
        c[7] = light_color;
    }
    return c[i];
}

// Paints a shape (distance d < 0 inside) with a dark outline of width ow around it.
vec3 paint(vec3 col, float d, vec3 fill, float ow, float px) {
    col = mix(col, rugColor(6), 1.0 - smoothstep(-px, px, d - ow));
    return mix(col, fill, 1.0 - smoothstep(-px, px, d));
}

// A petal along +x from the origin: half-length len, half-width wid.
float petal(vec2 q, float len, float wid) {
    float r = 0.5 * (len * len / wid + wid);
    float d = 0.5 * (len * len / wid - wid);
    return sdVesica(vec2(q.y, q.x - len), r, d);
}

// A ring of n petals at radius rad, turned by rot.
float petalRing(vec2 q, float n, float rad, float len, float wid, float rot) {
    q = domPolar(rot2(-rot) * q, n);
    return petal(q - vec2(rad - len, 0.0), len, wid);
}

// The outline of the medallion (style 0-3) with radius R and n points.
float medallionShape(vec2 q, float R, int style, float n) {
    float len = length(q);
    float a = atan(q.y, q.x) + 0.5 * PI;
    if (style == 0) {
        float r = R * (0.84 + 0.16 * sqrt(abs(cos(0.5 * n * a))));
        return (len - r) * 0.75;
    } else if (style == 1) {
        return sdStar(q, R, int(n), max(2.0, n * 0.38));
    } else if (style == 2) {
        float st = R / 7.0;                          // stepped, like a tribal rug
        vec2 qs = (floor(q / st) + 0.5) * st;
        return sdRhombus(qs, vec2(R * 0.82, R * 1.1));
    }
    return len - R * (0.94 + 0.06 * cos(2.0 * n * a));
}

float medallionMorph(vec2 q, float R, float n, float m) {
    float a = medallionShape(q, R, medallion_shape, n);
    if (m <= 0.0) return a;
    return mix(a, medallionShape(q, R, medallion_shape_b, n), m);
}

// Morph weight 0..1 of the second shape at time t (A, morph to B, B, morph back).
float morphWeight(float t) {
    if (morph_every <= 0) return 0.0;
    float e = float(morph_every);
    float len = min(morph_beats, e);
    float ph = mod(t, 2.0 * e);
    return smoothstep(e - len, e, ph) * (1.0 - smoothstep(2.0 * e - len, 2.0 * e, ph));
}

// The whole medallion (layers, pendants) around the origin.
vec3 medallion(vec3 col, vec2 q, float R, float px, float t, float m, float glow) {
    float n = float(medallion_points);
    float ow = R * 0.025 + px;
    float spin = TAU * medallion_spin * t / 32.0;
    vec2 qe = vec2(q.x, q.y / 1.2);              // a little taller than wide
    // pendants above and below
    vec2 pq = vec2(q.x, abs(q.y) - R * 1.2 - R * 0.2);
    float pend = min(sdRhombus(pq, vec2(R * 0.13, R * 0.2)), length(pq - vec2(0.0, R * 0.25)) - R * 0.06);
    col = paint(col, pend, rugColor(2) * (1.0 + glow), ow, px);
    col = paint(col, medallionMorph(qe, R, n, m), rugColor(2) * (1.0 + glow), ow, px);
    // arabesque petals and a ring of beads in the outer band
    col = paint(col, petalRing(qe, 2.0 * n, R * 0.95, R * 0.09, R * 0.032, -spin * 0.25), rugColor(4), ow * 0.5, px);
    vec2 bq = domPolar(rot2(spin * 0.25) * qe, 4.0 * n);
    col = mix(col, rugColor(7), 1.0 - smoothstep(-px, px, length(bq - vec2(R * 0.79, 0.0)) - R * 0.022));
    col = paint(col, medallionMorph(qe, R * 0.74, n, m), rugColor(3), ow, px);
    col = paint(col, petalRing(q, n, R * 0.62, R * 0.16, R * 0.06, spin), rugColor(4) * (1.0 + glow), ow * 0.7, px);
    col = paint(col, medallionMorph(rot2(-spin * 0.5) * q, R * 0.36, n, m), rugColor(0), ow, px);
    col = paint(col, petalRing(q, n, R * 0.3, R * 0.12, R * 0.045, -spin), rugColor(7), ow * 0.6, px);
    col = paint(col, length(q) - R * 0.07, rugColor(4) * (1.0 + 2.0 * glow), ow * 0.6, px);
    return col;
}

// The field: flowers on a lattice of vines, moved by the scroll.
vec3 field(vec2 fp, float px, float t) {
    vec3 col = rugColor(0);
    float dens = field_density * 0.5;
    vec2 q = fp * dens;
    float pxq = px * dens;
    // the vines: diagonal lines through all flowers, a little wavy
    float u = q.x - q.y + 0.06 * sin(TAU * (q.x + q.y));
    float v = q.x + q.y + 0.06 * sin(TAU * (q.x - q.y));
    float dv = min(abs(fract(u + 0.5) - 0.5), abs(fract(v + 0.5) - 0.5)) * 0.7071;
    col = mix(col, rugColor(5), 1.0 - smoothstep(0.018 - pxq, 0.018 + pxq, dv));
    // two flowers per cell: a big rosette on the corners, a small four-petal flower in the middle
    vec2 a = fract(q) - 0.5, b = fract(q + 0.5) - 0.5;
    bool big = dot(b, b) < dot(a, a);
    vec2 l = big ? b : a;
    vec2 id = floor(big ? q + 0.5 : q) + (big ? vec2(0.0) : vec2(0.5));
    float h = hash12(floor(id * 2.0) + float(seed) * 13.7);
    float lit = beat_pulse * exp(-5.0 * fract(t)) * step(h, twinkle);
    float ow = 0.02 + pxq;
    if (big) {
        // four lancet leaves along the vines (the herati motif), then the rosette
        float leaf = petalRing(l, 4.0, 0.42, 0.13, 0.04, 0.25 * PI);
        col = paint(col, leaf, rugColor(5), ow * 0.6, pxq);
        col = paint(col, petalRing(l, 8.0, 0.2, 0.1, 0.045, 0.0), rugColor(4) * (1.0 + lit), ow * 0.6, pxq);
        col = paint(col, length(l) - 0.06, rugColor(7) * (1.0 + lit), ow * 0.6, pxq);
    } else {
        col = paint(col, petalRing(l, 4.0, 0.13, 0.07, 0.035, 0.0), rugColor(7) * (1.0 + lit), ow * 0.5, pxq);
        col = paint(col, length(l) - 0.03, rugColor(1), ow * 0.4, pxq);
    }
    return col;
}

// A guard band: a small zigzag of two colours (the "reciprocal" border), v across 0..1.
vec3 guardBand(float u, float v, float px) {
    float z = abs(fract(u) - 0.5) * 2.0;
    float edge = (v - z) * 0.5;
    vec3 col = mix(rugColor(7), rugColor(1), smoothstep(-px, px, edge));
    return col;
}

// The main border: rosettes and cartouches on a vine; bx along (carpet units, scrolled), by across (-hw..hw).
vec3 mainBorder(float bx, float by, float period, float hw, float px, float t) {
    vec3 col = rugColor(1);
    float k = floor(bx / period);
    vec2 q = vec2((fract(bx / period) - 0.5) * period, by);
    float vine = abs(by - hw * 0.45 * sin(TAU * bx / period));
    col = mix(col, rugColor(5), 1.0 - smoothstep(hw * 0.05 - px, hw * 0.05 + px, vine));
    float ow = hw * 0.06 + px;
    float lit = beat_pulse * exp(-5.0 * fract(t)) * 0.6;
    if (mod(k, 2.0) < 0.5) {
        col = paint(col, medallionShape(q, hw * 0.62, 0, 8.0), rugColor(0) * (1.0 + lit), ow, px);
        col = paint(col, petalRing(q, 8.0, hw * 0.4, hw * 0.12, hw * 0.05, 0.0), rugColor(4), ow * 0.6, px);
        col = paint(col, length(q) - hw * 0.12, rugColor(7), ow * 0.6, px);
    } else {
        float cart = sdRhombus(q, vec2(period * 0.42, hw * 0.55));
        col = paint(col, cart, rugColor(3), ow, px);
        col = paint(col, petal(abs(q) - vec2(period * 0.06, 0.0), period * 0.12, hw * 0.12), rugColor(0), ow * 0.6, px);
    }
    return col;
}

vec3 carpetColor(vec2 wp, float px, float t) {
    vec2 pw = warpDomain(wp, t);
    float m = morphWeight(t);
    vec2 H, c, fp;
    if (carpet_layout == 1) {
        H = vec2(carpet_size * carpet_aspect, carpet_size);
        vec2 cell = moveCarpet(pw, t, 2.0 * H);
        c = mod(cell + H, 2.0 * H) - H;
        fp = cell;
    } else {
        H = carpet_layout == 0 ? wallHalfSize() : vec2(1e4);
        c = pw;
        fp = moveCarpet(pw, t, vec2(1024.0) / max(field_density, 1.0));
    }
    float hs = min(H.x, H.y);                   // carpet half-height: the unit of the sizes
    float bw = carpet_layout == 2 ? 0.0 : border_width * hs;
    float gw = bw * 0.28;                        // guard bands
    float e = min(H.x - abs(c.x), H.y - abs(c.y));   // distance in from the outer edge

    vec3 col = field(fp, px, t);
    if (carpet_layout != 2) {
        vec2 F = H - (bw + 2.0 * gw) - 0.02 * hs;     // the field inside the border
        float glow = beat_pulse * 0.5 * exp(-4.0 * fract(t));
        float R = medallion_size * hs * (1.0 + 0.05 * breathe * sin(TAU * loopPhase(t)));
        if (corner_size > 0.0) {
            vec2 cq = abs(c) - F;
            col = medallion(col, cq, corner_size * hs, px, t, m, 0.0);
        }
        if (medallion_size > 0.0)
            col = medallion(col, c, R, px, t, m, glow);
        // a thin frame around the field, then the border
        if (bw > 0.0) {
            float fe = min(F.x - abs(c.x), F.y - abs(c.y));
            col = mix(col, rugColor(6), 1.0 - smoothstep(-px, px, fe - 0.008 * hs));
            col = mix(col, rugColor(7), 1.0 - smoothstep(-px, px, fe));
            // position along the frame, clockwise from the top left corner
            float s;
            if (H.y - abs(c.y) < H.x - abs(c.x))
                s = c.y > 0.0 ? c.x + H.x : 2.0 * H.x + 2.0 * H.y + (H.x - c.x);
            else
                s = c.x > 0.0 ? 2.0 * H.x + (H.y - c.y) : 4.0 * H.x + 2.0 * H.y + (c.y + H.y);
            float perim = 4.0 * (H.x + H.y);
            float nMotif = max(4.0, floor(perim / (bw * 2.2) / 2.0 + 0.5) * 2.0);   // even: rosette, cartouche
            float period = perim / nMotif;
            float run = mod(border_run * t, nMotif) * period;
            if (e < bw + 2.0 * gw + 0.02 * hs) {
                vec3 b;
                if (e < gw)
                    b = guardBand((s + run) / period * 6.0, e / gw, px / gw);
                else if (e < gw + bw)
                    b = mainBorder(s + run, e - gw - 0.5 * bw, period, 0.5 * bw, px, t);
                else
                    b = guardBand((s - run) / period * 6.0, 1.0 - (e - gw - bw) / gw, px / gw);
                col = b;
                // dark lines between the bands
                float l1 = abs(e - gw), l2 = abs(e - gw - bw);
                col = mix(col, rugColor(6), 1.0 - smoothstep(0.006 * hs, 0.006 * hs + px, min(l1, l2)));
            }
            // outside the carpet (a warp can pull its edge into the picture): dark
            col = mix(col, rugColor(6) * 0.5, 1.0 - smoothstep(-px, px, e));
        }
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float t = carpetTime();
    vec2 fc = ledCentre(fragCoord);
    float led = ledSize();
    int ns = clamp(quality, 1, 3);
    float px = 2.0 * led / iResolution.y * softness / float(ns);
    vec3 col = vec3(0.0);
    for (int j = 0; j < ns; j++) {
        for (int i = 0; i < ns; i++) {
            vec2 o = (vec2(float(i), float(j)) + 0.5) / float(ns) - 0.5;
            col += carpetColor(wallPosition(fc + o * led), px, t);
        }
    }
    col /= float(ns * ns);
    // wool: the knots as soft dots, and the abrash (stripes where a new batch of dye was used)
    vec2 wp = wallPosition(fc);
    float kp = knot_size * led;
    vec2 kq = fract(fragCoord / kp) - 0.5;
    col *= 1.0 - knots * 0.22 * smoothstep(0.15, 0.5, length(kq)) * step(1.5, kp);
    float ab = gradientNoise(vec2(wp.y * 2.3, 0.5 + float(seed)));
    col *= 1.0 + abrash * 0.22 * ab;
    fragColor = vec4(ledOutput(col), 1.0);
}
