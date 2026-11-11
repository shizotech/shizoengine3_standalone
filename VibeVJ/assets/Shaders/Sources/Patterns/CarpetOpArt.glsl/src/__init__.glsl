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

// ---- shader ----
// CarpetOpArt: op-art and Art-Deco tilings for big LED walls: woven Truchet arcs, Deco fans (overlapping scales with
// sunbursts), a Vasarely bulge (a checkerboard pushed out by a moving sphere) and Riley waves (stripes bent by
// travelling waves). The patterns change through an iris on the beat. Time counts beats in Sync.

//@enum options=(Truchet weave, Deco fans, Vasarely bulge, Riley waves) value=0
uniform int pattern;
//@enum options=(Truchet weave, Deco fans, Vasarely bulge, Riley waves) value=2
uniform int pattern_b;        // the pattern the iris opens to, and back
//@int min=0 max=64 value=16
uniform int morph_every;      // beats between the changes; 0 = only the first pattern
//@slider min=0.25 max=16.0 value=4.0
uniform float morph_beats;    // how long the iris takes, in beats
//@slider min=1.0 max=24.0 value=6.0
uniform float scale;          // tiles across the height of one screen
//@int min=1 max=6 value=3
uniform int bands;            // stripes in each arc, ring or scale
//@slider min=0.05 max=0.95 value=0.5
uniform float line_ratio;     // share of the light colour in the stripes
//@slider min=0.0 max=2.0 value=1.0
uniform float bulge;          // Vasarely bulge: how far the sphere pushes out
//@slider min=0.2 max=2.0 value=0.8
uniform float bulge_size;     // its radius in screen heights
//@slider min=0.0 max=2.0 value=0.5
uniform float wave_amount;    // Riley waves: how far the stripes bend
//@slider min=-2.0 max=2.0 value=0.5
uniform float flow;           // stripes, rings and arcs flowing per beat
//@int min=0 max=64 value=8
uniform int flip_every;       // Truchet weave: tiles turn every this many beats, a few at a time; 0 = never
//@enum options=(Black and white, Deco gold, Riley colour, Neon, Custom colours) value=1
uniform int palette;
//@rgb value=(0.03, 0.03, 0.04)
uniform vec3 dark_color;      // Custom colours
//@rgb value=(0.95, 0.93, 0.88)
uniform vec3 light_color;
//@rgb value=(0.85, 0.62, 0.25)
uniform vec3 accent_color;
//@slider min=0.0 max=1.0 value=0.5
uniform float shading;        // depth: shadows under the arcs, light on the bulge
//@slider min=0.0 max=1.0 value=0.35
uniform float beat_pulse;     // the light colour flashes on the beat
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

void opColors(out vec3 dark, out vec3 light, out vec3 accent) {
    if (palette == 0) { dark = vec3(0.02); light = vec3(0.95); accent = vec3(0.55); }
    else if (palette == 1) { dark = vec3(0.04, 0.05, 0.07); light = vec3(0.92, 0.76, 0.42); accent = vec3(0.10, 0.42, 0.42); }
    else if (palette == 2) { dark = vec3(0.10, 0.12, 0.30); light = vec3(0.96, 0.93, 0.86); accent = vec3(0.95, 0.42, 0.33); }
    else if (palette == 3) { dark = vec3(0.01, 0.0, 0.03); light = vec3(0.10, 0.95, 1.0); accent = vec3(1.0, 0.10, 0.60); }
    else { dark = dark_color; light = light_color; accent = accent_color; }
}

// Box-filtered stripes: 1 on the light part of a period of 1 (share line_ratio), filtered over w.
float stripes(float x, float w) {
    float r = clamp(line_ratio, 0.05, 0.95);
    float f = fract(x);
    float a = smoothstep(-w, w, f - (1.0 - r) * 0.5) - smoothstep(-w, w, f - (1.0 + r) * 0.5);
    return w > 0.35 ? r : a;
}

// Truchet weave: quarter arcs of bands stripes; tiles turn on the beat.
vec3 truchet(vec2 p, float px, float t, vec3 dark, vec3 light, vec3 accent) {
    vec2 id = floor(p);
    vec2 q = p - id - 0.5;
    float h = hash12(id + float(seed) * 11.0);
    float turn = floor(h * 2.0);
    if (flip_every > 0) {
        // a quarter of the tiles turns by a quarter at every step (each tile every fourth step), each at its own
        // moment of the first beat of the step
        float e = float(flip_every);
        float k = floor(t / e) + floor(hash12(id + 7.0 + float(seed)) * 4.0);
        float when = hash12(id + 3.0) * 0.6;
        float f = smoothstep(when, when + 0.4, fract(t / e) * e);
        turn += floor(k / 4.0) - (mod(k, 4.0) < 0.5 ? 1.0 - f : 0.0);
    }
    q = rot2(turn * 0.5 * PI) * q;
    // two arcs around opposite corners; the second one goes under the first
    float d1 = abs(length(q - 0.5) - 0.5);
    float d2 = abs(length(q + 0.5) - 0.5);
    float wA = 0.5 * 0.62;                      // half-width of an arc
    vec3 col = dark;
    float under = 1.0 - smoothstep(wA - px, wA + px, d2);
    float over = 1.0 - smoothstep(wA - px, wA + px, d1);
    float s2 = stripes(d2 / wA * float(bands) * 0.5 - flow * t, px / wA * float(bands) * 0.5);
    float s1 = stripes(d1 / wA * float(bands) * 0.5 - flow * t, px / wA * float(bands) * 0.5);
    vec3 c2 = mix(accent, light, s2);
    vec3 c1 = mix(accent, light, s1);
    col = mix(col, c2, under);
    // a shadow of the upper arc on the lower one
    col *= 1.0 - shading * 0.5 * (1.0 - smoothstep(wA, wA + 0.12, d1)) * under * (1.0 - over);
    col = mix(col, c1, over);
    col = mix(col, dark, (1.0 - smoothstep(0.0, px * 1.5, abs(d1 - wA))) * 0.8);
    return col;
}

// Deco fans: overlapping scales in rows (seigaiha) with rings and a sunburst.
vec3 decoFans(vec2 p, float px, float t, vec3 dark, vec3 light, vec3 accent) {
    vec2 s = vec2(p.x, p.y * 2.0);             // rows of half a tile
    float row = floor(s.y);
    vec3 col = dark;
    // the front scale is the one of the lowest row that holds the point
    for (int k = 0; k < 3; k++) {
        float r = row - float(k) + 1.0;
        float off = mod(r, 2.0) * 0.5;
        float cx = floor(p.x - off + 0.5) + off;
        for (int n = -1; n <= 1; n++) {
            vec2 c = vec2(cx + float(n), r * 0.5);
            vec2 q = p - c;
            float d = length(q);
            if (d < 0.5 + px && q.y > -0.02) {
                float inside = 1.0 - smoothstep(0.5 - px, 0.5 + px, d);
                float ring = stripes(d * 2.0 * float(bands) - flow * t, px * 2.0 * float(bands));
                float a = atan(q.x, max(q.y, 1e-4));
                float rays = stripes(a / PI * 9.0, px / max(d, 0.05) * 9.0 / PI);
                vec3 fan = mix(dark, light, ring);
                float core = 1.0 - smoothstep(0.5 / float(bands + 1) - px, 0.5 / float(bands + 1) + px, d);
                fan = mix(fan, mix(accent, light, rays), core + (1.0 - core) * step(float(bands) * 0.5, 0.0));
                fan *= 1.0 - shading * 0.35 * smoothstep(0.3, 0.5, d);
                col = mix(col, fan, inside);
                col = mix(col, light, (1.0 - smoothstep(0.0, px * 1.5, abs(d - 0.5))) * inside);
            }
        }
    }
    return col;
}

// Vasarely bulge: a checkerboard with circles, pushed out by a sphere that moves on a loop.
vec3 vasarely(vec2 wp, vec2 p0, float px, float t, vec3 dark, vec3 light, vec3 accent) {
    float ph = TAU * loopPhase(t);
    float S = scale * 0.5;
    vec2 c = vec2(0.5 * sin(ph), 0.3 * sin(2.0 * ph)) * min(screenAspect(), 2.0);
    vec2 d = wp - c;
    float R = bulge_size * (1.0 + beat_pulse * 0.1 * exp(-5.0 * fract(t)));
    float r = length(d) / R;
    float z = r < 1.0 ? sqrt(1.0 - r * r) : 0.0;
    // the sphere pulls the grid towards its middle: the tiles on it look bigger
    vec2 p = p0 - d * S * bulge * 0.55 * z;
    vec2 id = floor(p);
    vec2 q = p - id - 0.5;
    float chk = mod(id.x + id.y, 2.0);
    vec3 a = chk < 0.5 ? dark : light;
    vec3 b = chk < 0.5 ? light : dark;
    // circles in the squares: bigger on the sphere, coloured by the height
    float cr = 0.16 + 0.26 * z * min(bulge, 1.0) + 0.06 * sin(TAU * (flow * t + dot(id, vec2(0.13, 0.07))));
    float circ = 1.0 - smoothstep(cr - px, cr + px, length(q));
    vec3 col = mix(a, mix(b, accent, z * 0.8), circ);
    col *= 1.0 + shading * (0.35 * z - 0.15 * (1.0 - z) * step(r, 1.4));
    return col;
}

// Riley waves: stripes bent by waves travelling down the picture.
vec3 riley(vec2 p, float px, float t, vec3 dark, vec3 light, vec3 accent) {
    float ph = TAU * flow * t / 4.0;
    float wave = wave_amount * (0.35 * sin(p.y * 0.9 + ph) + 0.2 * sin(p.y * 2.1 - ph * 1.3 + p.x * 0.15));
    float x = p.x * float(bands) * 0.5 + wave * float(bands);
    // the slope of the wave makes the stripes thinner: filter by it
    float dw = abs(wave_amount * float(bands) * (0.35 * 0.9 + 0.2 * 2.1)) * 0.5 + 1.0;
    float s = stripes(x, px * float(bands) * 0.5 * dw);
    vec3 lightC = mix(light, accent, 0.5 + 0.5 * sin(p.y * 0.4 + ph * 0.5));
    return mix(dark, lightC, s);
}

vec3 patternColor(int pat, vec2 wp, vec2 p, float px, float t) {
    vec3 dark, light, accent;
    opColors(dark, light, accent);
    light *= 1.0 + beat_pulse * 0.5 * exp(-5.0 * fract(t));
    if (pat == 0) return truchet(p, px, t, dark, light, accent);
    if (pat == 1) return decoFans(p, px, t, dark, light, accent);
    if (pat == 2) return vasarely(wp, p, px, t, dark, light, accent);
    return riley(p, px, t, dark, light, accent);
}

// Morph weight 0..1 of the second pattern at time t.
float morphWeight(float t) {
    if (morph_every <= 0) return 0.0;
    float e = float(morph_every);
    float len = min(morph_beats, e);
    float ph = mod(t, 2.0 * e);
    return smoothstep(e - len, e, ph) * (1.0 - smoothstep(2.0 * e - len, 2.0 * e, ph));
}

vec3 carpetColor(vec2 wp, float px, float t) {
    vec2 pw = warpDomain(wp, t);
    vec2 p = moveCarpet(pw * scale * 0.5, t, vec2(512.0));
    float pxT = px * scale * 0.5;
    float m = morphWeight(t);
    vec3 col = patternColor(pattern, pw, p, pxT, t);
    if (m > 0.0) {
        // an iris from the middle of the wall: inside it the second pattern, a light ring at its edge
        vec2 hw = wallHalfSize();
        float rad = m * length(hw) * 1.05;
        float dd = length(wp) - rad;
        float inB = 1.0 - smoothstep(-px, px, dd);
        if (inB > 0.0) col = mix(col, patternColor(pattern_b, pw, p, pxT, t), inB);
        vec3 dark, light, accent;
        opColors(dark, light, accent);
        col = mix(col, accent, (1.0 - smoothstep(0.0, 0.02 + px, abs(dd))) * step(m, 0.999));
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
    fragColor = vec4(ledOutput(col), 1.0);
}
