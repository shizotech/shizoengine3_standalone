//@settings dtype=float32 format=rgba

// Library code below is bundled from shader-skills (MIT): https://github.com/gokayfem/shader-skills
// ---- shader-skills library: common ----
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

// ---- shader ----
// CarpetKilim: woven patterns on a grid of stitches, made for LED walls (a stitch can be exactly one LED):
// Anatolian kilim (stepped diamonds with hooks in bands), ikat (feathered warp-dyed eyes), Navajo eye-dazzler
// (serrated diamonds of thin stripes) and kente (strips of blocks). The rings flow outwards, the strips slide, the
// colours step on the beat, and the loom weaves the next pattern in row by row. Time counts beats in Sync.

//@enum options=(Kilim, Ikat, Eye-dazzler, Kente) value=0
uniform int pattern;
//@enum options=(Kilim, Ikat, Eye-dazzler, Kente) value=2
uniform int pattern_b;        // the pattern the loom weaves in, and back
//@int min=0 max=64 value=16
uniform int morph_every;      // beats between the changes; 0 = only the first pattern
//@slider min=0.25 max=16.0 value=4.0
uniform float morph_beats;    // how long weaving in takes, in beats
//@slider min=1.0 max=24.0 value=4.0
uniform float stitch;         // size of one stitch in LED pixels (in pixels when led_pixel is off)
//@int min=8 max=96 value=28
uniform int motif_size;       // height of a band / a motif in stitches
//@slider min=-2.0 max=2.0 value=0.5
uniform float ring_flow;      // rings per beat flowing out of the diamonds and eyes
//@slider min=0.0 max=2.0 value=0.5
uniform float strip_slide;    // Kente: the strips slide up and down, blocks per beat
//@slider min=0.0 max=1.0 value=0.5
uniform float bleed;          // Ikat: how far the dye runs along the threads
//@int min=0 max=32 value=4
uniform int color_step_every; // beats: the colours move one step through the palette; 0 = never
//@enum options=(Auto, Anatolian, Indigo, Navajo, Kente, Neon, Custom colours) value=0
uniform int palette;          // Auto: the classic colours of each pattern
//@rgb value=(0.62, 0.10, 0.08)
uniform vec3 color_1;         // Custom colours
//@rgb value=(0.10, 0.14, 0.38)
uniform vec3 color_2;
//@rgb value=(0.92, 0.70, 0.18)
uniform vec3 color_3;
//@rgb value=(0.93, 0.89, 0.78)
uniform vec3 color_4;
//@rgb value=(0.10, 0.07, 0.06)
uniform vec3 color_5;
//@slider min=0.0 max=1.0 value=0.5
uniform float weave;          // the texture of the yarn: rows of weft, each stitch a little different
//@slider min=0.0 max=1.0 value=0.4
uniform float beat_pulse;     // the pattern flashes brighter on the beat
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

// Palette p, colour i (0..4).
vec3 kilimColor(int p, float fi) {
    int i = int(mod(fi, 5.0));
    vec3 c[5];
    if (p == 1) {        // Anatolian: madder, indigo, saffron, undyed wool, walnut
        c[0] = vec3(0.64, 0.10, 0.08); c[1] = vec3(0.10, 0.15, 0.40); c[2] = vec3(0.93, 0.68, 0.16);
        c[3] = vec3(0.92, 0.87, 0.74); c[4] = vec3(0.12, 0.08, 0.06);
    } else if (p == 2) { // Indigo: ikat blues, white, red, yellow
        c[0] = vec3(0.06, 0.12, 0.42); c[1] = vec3(0.92, 0.93, 0.95); c[2] = vec3(0.72, 0.08, 0.12);
        c[3] = vec3(0.95, 0.80, 0.20); c[4] = vec3(0.16, 0.40, 0.75);
    } else if (p == 3) { // Navajo: red, black, white, grey, orange
        c[0] = vec3(0.72, 0.06, 0.05); c[1] = vec3(0.04, 0.04, 0.04); c[2] = vec3(0.94, 0.92, 0.88);
        c[3] = vec3(0.50, 0.48, 0.46); c[4] = vec3(0.95, 0.45, 0.08);
    } else if (p == 4) { // Kente: gold, green, red, black, blue
        c[0] = vec3(0.95, 0.72, 0.10); c[1] = vec3(0.05, 0.45, 0.20); c[2] = vec3(0.78, 0.10, 0.08);
        c[3] = vec3(0.04, 0.04, 0.04); c[4] = vec3(0.10, 0.25, 0.65);
    } else if (p == 5) { // Neon
        c[0] = vec3(1.00, 0.10, 0.55); c[1] = vec3(0.02, 0.02, 0.06); c[2] = vec3(0.10, 0.95, 1.00);
        c[3] = vec3(1.00, 0.85, 0.10); c[4] = vec3(0.45, 0.10, 1.00);
    } else {
        c[0] = color_1; c[1] = color_2; c[2] = color_3; c[3] = color_4; c[4] = color_5;
    }
    return c[i];
}

int paletteFor(int pat) {
    if (palette > 0) return palette;
    return pat == 0 ? 1 : (pat == 1 ? 2 : (pat == 2 ? 3 : 4));
}

// Each pattern returns a colour index for the stitch s (integer stitch coordinates) at time t.

float kilimPattern(vec2 s, float t) {
    float H = float(motif_size);
    float band = floor(s.y / H);
    float y = s.y - band * H;                   // 0 .. H-1 in the band
    float hb = hash11(band + float(seed) * 7.0);
    float mainH = floor(H * 0.72);
    if (y >= mainH) {
        // the narrow stripes between the bands, with a small zigzag
        float r = y - mainH;
        float zz = abs(mod(s.x, 6.0) - 3.0);
        float stripeH = H - mainH;
        if (abs(r - stripeH * 0.5 + 0.5 - (zz - 1.5)) < 0.75) return 3.0;
        return r < 1.0 || r >= stripeH - 1.0 ? 4.0 : 0.0 + floor(hb * 2.0);
    }
    float R = floor(mainH * 0.5) - 1.0;          // wallHalf-size of the big diamonds
    float P = 2.0 * R + 4.0;                    // their spacing
    float x = s.x + floor(hb * P);              // each band starts at another place
    float cx = (floor(x / P) + 0.5) * P;
    float cy = floor(mainH * 0.5);
    vec2 q = vec2(x - cx, y - cy);
    float d = abs(q.x) + abs(q.y);              // stepped diamond (L1 distance)
    float ground = 0.0 + floor(hb * 3.0);
    if (d <= R) {
        float ring = floor((d - ring_flow * t * 2.0) / 2.0);
        return 1.0 + mod(ring + floor(hb * 4.0), 4.0);
    }
    // latch hooks on the outside of the diamond edges
    float along = abs(q.x) - abs(q.y);
    if (d <= R + 3.0 && mod(along + 64.0, 4.0) < 2.0 && d > R + 0.5) return 4.0;
    // small diamonds in the gaps between the big ones, above and below
    vec2 q2 = vec2(x - (floor(x / P) * P), y - (y < cy ? 2.0 : mainH - 3.0));
    if (abs(q2.x) + abs(q2.y) <= 2.0 || abs(q2.x - P) + abs(q2.y) <= 2.0) return 3.0;
    return ground;
}

float ikatPattern(vec2 s, float t) {
    float W = float(motif_size);
    float H = W * 1.5;
    // every warp thread (column) is shifted a little: the dye ran along it
    float col = s.x;
    float j = (hash11(col + float(seed) * 3.0) - 0.5) * bleed * W * 0.25
            + bleed * W * 0.08 * sin(col * 0.37 + TAU * loopPhase(t));
    vec2 p = vec2(s.x, s.y + floor(j));
    float row = floor(p.y / H);
    float x = p.x + mod(row, 2.0) * W * 0.5;
    vec2 q = vec2(x - (floor(x / W) + 0.5) * W, p.y - (row + 0.5) * H);
    vec2 a = abs(q) / vec2(W * 0.5, H * 0.5);
    float dn = pow(pow(a.x, 1.4) + pow(a.y, 1.4), 1.0 / 1.4);
    float ring = floor(dn * 5.0 - ring_flow * t);
    float k = mod(ring, 4.0);
    return dn > 1.0 ? 0.0 : (k < 1.0 ? 1.0 : (k < 2.0 ? 2.0 : (k < 3.0 ? 0.0 : 3.0)));
}

float dazzlerPattern(vec2 s, float t) {
    float S = float(motif_size);
    vec2 uv = vec2(s.x + s.y, s.x - s.y);        // diamond lattice
    vec2 c = (floor(uv / S) + 0.5) * S;
    vec2 q = uv - c;
    float d = max(abs(q.x), abs(q.y)) * 0.5;
    float along = abs(q.x) > abs(q.y) ? q.y : q.x;
    float serr = abs(mod(along, 4.0) - 2.0) * 0.5;   // the serrated (zigzag) edges
    float ring = floor((d + serr) / 1.5 - ring_flow * t);
    float h = hash12(floor(uv / S) + float(seed));
    float k = mod(ring + floor(h * 2.0) * 2.0, 6.0);
    return k < 1.0 ? 0.0 : (k < 2.0 ? 2.0 : (k < 3.0 ? 1.0 : (k < 4.0 ? 3.0 : (k < 5.0 ? 2.0 : 4.0))));
}

float kentePattern(vec2 s, float t) {
    float W = floor(float(motif_size) * 0.6);
    float strip = floor(s.x / W);
    float dir = mod(strip, 2.0) < 0.5 ? 1.0 : -1.0;
    float B = W;
    float y = s.y + dir * floor(strip_slide * t * B);   // strip_slide blocks per beat
    float block = floor(y / B);
    vec2 q = vec2(s.x - strip * W, y - block * B);
    float h = hash12(vec2(strip, block) + float(seed) * 1.7);
    float base = floor(h * 5.0);
    float ty = floor(hash11(strip * 13.0 + block + float(seed)) * 4.0);
    if (q.x < 1.0) return 3.0;                  // a dark thread between the strips
    if (ty < 1.0) return mod(base + floor(q.y / 2.0), 2.0) < 1.0 ? base : 0.0;
    if (ty < 2.0) return mod(floor(q.x / 2.0), 2.0) < 1.0 ? base : 1.0;
    if (ty < 3.0) return mod(floor(q.x / 2.0) + floor(q.y / 2.0), 2.0) < 1.0 ? base : 3.0;
    return abs(q.y - B * 0.5) < B * 0.18 ? 2.0 : base;
}

float patternIndex(int pat, vec2 s, float t) {
    if (pat == 0) return kilimPattern(s, t);
    if (pat == 1) return ikatPattern(s, t);
    if (pat == 2) return dazzlerPattern(s, t);
    return kentePattern(s, t);
}

// Morph weight 0..1 of the second pattern at time t (A, weave in B, B, weave A back in).
float morphWeight(float t) {
    if (morph_every <= 0) return 0.0;
    float e = float(morph_every);
    float len = min(morph_beats, e);
    float ph = mod(t, 2.0 * e);
    return clamp((ph - (e - len)) / len, 0.0, 1.0) * (1.0 - clamp((ph - (2.0 * e - len)) / len, 0.0, 1.0));
}

vec3 carpetColor(vec2 wp, float t, float shift) {
    vec2 pw = warpDomain(wp, t);
    float stitchW = 2.0 * stitch * ledSize() / iResolution.y;   // one stitch in wall units
    // scrolled in motifs (scroll_speed is motifs per 4 beats); the patterns repeat only far away, so the wrap of the
    // offset comes after 4096 motifs, later than the wrap of the time
    float ms = float(motif_size);
    vec2 sp = moveCarpet(pw / stitchW / ms, t, vec2(4096.0)) * ms;
    vec2 s = floor(sp);
    float m = morphWeight(t);
    // the loom weaves the second pattern in from the bottom; its edge is the row the shuttle is in
    vec2 wallHalf = wallHalfSize();
    float edgeY = mix(-wallHalf.y - 0.05, wallHalf.y + 0.05, m);
    bool useB = m > 0.0 && pw.y < edgeY;
    int pat = useB ? pattern_b : pattern;
    float idx = patternIndex(pat, s, t) + shift;
    vec3 col = kilimColor(paletteFor(pat), idx);
    // the yarn: a dark line between the weft rows, every stitch a little different
    vec2 f = sp - s;
    float yarn = hash12(s + float(seed) * 3.1);
    col *= 1.0 - weave * (0.18 * smoothstep(0.32, 0.5, abs(f.y - 0.5)) + 0.12 * (yarn - 0.5));
    col *= 1.0 - weave * 0.12 * abs(f.x - 0.5) * 2.0 * step(0.5, mod(s.x + s.y, 2.0));
    if (m > 0.0 && m < 1.0) {
        float shuttle = 1.0 - smoothstep(0.0, stitchW * 1.5, abs(pw.y - edgeY));
        col = mix(col, vec3(1.0, 0.95, 0.85), shuttle * 0.8);
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float t = carpetTime();
    vec2 fc = ledCentre(fragCoord);
    float led = ledSize();
    float shift = color_step_every > 0 ? floor(t / float(color_step_every)) : 0.0;
    int ns = clamp(quality, 1, 3);
    vec3 col = vec3(0.0);
    for (int j = 0; j < ns; j++) {
        for (int i = 0; i < ns; i++) {
            vec2 o = (vec2(float(i), float(j)) + 0.5) / float(ns) - 0.5;
            col += carpetColor(wallPosition(fc + o * led * min(softness, 1.0)), t, shift);
        }
    }
    col /= float(ns * ns);
    col *= 1.0 + beat_pulse * 0.35 * exp(-5.0 * fract(t));
    fragColor = vec4(ledOutput(col), 1.0);
}
