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

// ---- shader-skills library: pattern ----
// Hexagonal tiling with unit spacing between neighboring centers. Neighbors sit left/right, so hexes are pointy-top. Returns vec4(local offset from the hex center, integer-valued hex id).
vec4 hexGrid(vec2 p) {
    const vec2 s = vec2(1.0, 1.7320508);
    vec2 a = mod(p, s) - 0.5 * s;
    vec2 b = mod(p - 0.5 * s, s) - 0.5 * s;
    vec2 local = (dot(a, a) < dot(b, b)) ? a : b;
    vec2 center = p - local;
    vec2 id = floor(vec2(center.x * 2.0, center.y * 1.1547005) + 0.5);
    return vec4(local, id);
}

// ---- shader ----
// CarpetGirih: Islamic star patterns (girih, zellige) for big LED walls, drawn with Hankin's "polygons in contact"
// method: from the middle of every edge of a tiling two bands start at the contact angle and meet inside the tile.
// Four tilings with the symmetry of the wallpaper groups p4m and p6m, woven bands that go over and under, stars that
// breathe, and a morph from one tiling to another on the beat. Time counts beats in Sync.

//@enum options=(Squares p4m, Hexagons p6m, Octagons 4.8.8, Dodecagons 3.12.12) value=2
uniform int tiling;
//@enum options=(Squares p4m, Hexagons p6m, Octagons 4.8.8, Dodecagons 3.12.12) value=3
uniform int tiling_b;         // the second pattern; the carpet morphs to it and back
//@int min=0 max=64 value=16
uniform int morph_every;      // beats between the morphs; 0 = only the first tiling
//@slider min=0.25 max=16.0 value=4.0
uniform float morph_beats;    // how long a morph takes, in beats
//@slider min=0.5 max=16.0 value=2.5
uniform float scale;          // tiles across the height of one screen
//@slider min=5.0 max=88.0 value=63.0
uniform float contact_angle;  // degrees: low = the outlines of the tiles, 60-70 = classic stars, 88 = spokes
//@slider min=0.0 max=30.0 value=7.0
uniform float angle_breath;   // degrees the angle swings over loop_beats: the stars open and close
//@slider min=0.0 max=20.0 value=0.0
uniform float beat_twist;     // degrees added on every beat, fading out until the next
//@slider min=0.005 max=0.12 value=0.04
uniform float strap_width;    // width of the bands, in tiles
//@slider min=0.0 max=0.04 value=0.012
uniform float outline_width;  // dark edge of the bands, in tiles
//@slider min=0.0 max=1.0 value=0.8
uniform float interlace;      // the bands weave over and under each other where they cross
//@int min=0 max=6 value=2
uniform int echo_lines;       // thin lines inside the stars that follow their outline
//@enum options=(Fes zellige, Alhambra, Isfahan, Mamluk, Neon night, Custom colours) value=0
uniform int palette;
//@rgb value=(0.95, 0.92, 0.84)
uniform vec3 band_color;      // Custom colours: the bands
//@rgb value=(0.08, 0.10, 0.18)
uniform vec3 outline_color;   // Custom colours: the edges
//@rgb value=(0.05, 0.28, 0.62)
uniform vec3 star_color;      // Custom colours: the stars
//@rgb value=(0.10, 0.48, 0.36)
uniform vec3 star_color_b;    // Custom colours: the stars of the second kind of tile
//@rgb value=(0.80, 0.55, 0.18)
uniform vec3 ground_color;    // Custom colours: the shapes between the stars
//@int min=0 max=32 value=0
uniform int color_swap_every; // beats: the fill colours change places; 0 = never
//@slider min=0.0 max=1.0 value=0.5
uniform float glaze;          // glazed tiles: each one a little different, with a soft gloss
//@slider min=0.0 max=1.0 value=0.35
uniform float beat_pulse;     // the bands light up on the beat
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

const vec2 HEX_PERIOD = vec2(1.0, 1.7320508);

// The polygon of the tiling under p: its centre c, inradius r, number of edges n, the angle of one edge normal.
void tilePolygon(vec2 p, int t, out vec2 c, out float r, out float n, out float rot0, out float kind) {
    kind = 0.0;
    rot0 = 0.0;
    if (t == 0) {
        c = floor(p + 0.5); r = 0.5; n = 4.0;
    } else if (t == 1) {
        vec4 h = hexGrid(p);
        c = p - h.xy; r = 0.5; n = 6.0;
    } else if (t == 2) {
        c = floor(p + 0.5); r = 0.5; n = 8.0;
        vec2 q = p - c;
        if (abs(q.x) + abs(q.y) > 0.70710678) {
            c += 0.5 * sign(q); r = 0.20710678; n = 4.0; rot0 = 0.25 * PI; kind = 1.0;
        }
    } else {
        vec4 h = hexGrid(p);
        c = p - h.xy; r = 0.5; n = 12.0;
        vec2 q = h.xy;
        float a = atan(q.y, q.x);
        float ca = (floor((a - PI / 6.0) / (PI / 3.0) + 0.5)) * (PI / 3.0) + PI / 6.0;
        vec2 dir = vec2(cos(ca), sin(ca));
        if (dot(q, dir) > 0.5) {
            c += 0.57735027 * dir; r = 0.07735027; n = 3.0; rot0 = ca + PI; kind = 1.0;
        }
    }
}

// Hankin's pattern for one tiling. Returns vec4(band distance, signed distance to the star outline (< 0 inside the
// star), under-shadow 0..1, kind of tile) and the ids of the tile and of the shape around the vertex.
vec4 girih(vec2 p, int t, float theta, float bw, float gap, out vec2 tileId, out vec2 vertexId) {
    vec2 c; float r, n, rot0, kind;
    tilePolygon(p, t, c, r, n, rot0, kind);
    vec2 q = p - c;
    float sec = TAU / n;
    float a = atan(q.y, q.x) - rot0;
    float k = floor(a / sec + 0.5);
    float frame = rot0 + k * sec;
    vec2 lu = rot2(-frame) * q;              // edge normal along +x, its midpoint at (r, 0)
    float sg = lu.y < 0.0 ? -1.0 : 1.0;
    vec2 l = vec2(lu.x, abs(lu.y));
    float h = r * tan(PI / n);
    float sn = sin(theta), cs = cos(theta);
    float s = h / (cs + (h / r) * sn);       // where the band meets its mirror image on the line to the vertex
    vec2 M = vec2(r, 0.0);
    vec2 D = vec2(-sn, cs);
    vec2 w = l - M;
    float dBand = length(w - D * clamp(dot(w, D), 0.0, s));
    float side = dot(w, vec2(cs, sn));       // < 0 on the side of the centre: the star
    tileId = c;
    vertexId = floor((c + rot2(frame) * vec2(r, sg * h)) * 8.0 + 0.5);

    // over and under at the middle of the edge, where the band of this tile crosses the band of the next
    float shade = 1.0;
    vec2 wu = lu - M;
    float lim = (2.5 * bw + gap) / max(sin(PI - 2.0 * theta), 0.25);
    if (interlace > 0.0 && length(wu) < lim) {
        vec2 mWorld = c + rot2(frame) * M;
        float hm = hash12(floor(mWorld * 64.0 + 0.5) + float(seed) * 3.17);
        vec2 dir1 = rot2(frame) * vec2(-sn, cs);
        vec2 dir2 = rot2(frame) * vec2(-sn, -cs);
        float f1 = fract(atan(dir1.y, dir1.x) / PI + 1.0 + hm);
        float f2 = fract(atan(dir2.y, dir2.x) / PI + 1.0 + hm);
        float d1 = abs(dot(wu, vec2(cs, sn)));
        float d2 = abs(dot(wu, vec2(cs, -sn)));
        float dOver = f1 > f2 ? d1 : d2;
        float dUnder = f1 > f2 ? d2 : d1;
        if (dOver < bw + gap) dBand = mix(dBand, dOver, interlace);
        else dBand = mix(dBand, dUnder, interlace);
        if (dOver >= bw + gap)
            shade = mix(1.0, 0.5 + 0.5 * smoothstep(bw + gap, bw + gap + 2.0 * bw, dOver), interlace);
    }
    return vec4(dBand, side, shade, kind);
}

// Morph weight 0..1 of the second tiling at time t (A, morph to B, B, morph back).
float morphWeight(float t) {
    if (morph_every <= 0) return 0.0;
    float e = float(morph_every);
    float len = min(morph_beats, e);
    float ph = mod(t, 2.0 * e);
    return smoothstep(e - len, e, ph) * (1.0 - smoothstep(2.0 * e - len, 2.0 * e, ph));
}

void paletteColors(out vec3 band, out vec3 edge, out vec3 starA, out vec3 starB, out vec3 ground) {
    if (palette == 0) {        // Fes zellige: cobalt, emerald, ochre on white
        band = vec3(0.95, 0.93, 0.86); edge = vec3(0.07, 0.09, 0.16);
        starA = vec3(0.06, 0.25, 0.62); starB = vec3(0.05, 0.45, 0.33); ground = vec3(0.86, 0.58, 0.16);
    } else if (palette == 1) { // Alhambra: gold bands, red, blue, green
        band = vec3(0.93, 0.76, 0.38); edge = vec3(0.16, 0.08, 0.04);
        starA = vec3(0.62, 0.12, 0.08); starB = vec3(0.10, 0.22, 0.48); ground = vec3(0.12, 0.40, 0.26);
    } else if (palette == 2) { // Isfahan: turquoise and cobalt, sand, saffron
        band = vec3(0.96, 0.90, 0.74); edge = vec3(0.05, 0.10, 0.22);
        starA = vec3(0.10, 0.62, 0.70); starB = vec3(0.08, 0.20, 0.58); ground = vec3(0.92, 0.70, 0.18);
    } else if (palette == 3) { // Mamluk: ivory, black, red
        band = vec3(0.92, 0.87, 0.76); edge = vec3(0.03, 0.03, 0.03);
        starA = vec3(0.55, 0.06, 0.05); starB = vec3(0.10, 0.10, 0.10); ground = vec3(0.70, 0.52, 0.30);
    } else if (palette == 4) { // Neon night: glowing bands on black
        band = vec3(0.10, 0.95, 0.90); edge = vec3(0.0); starA = vec3(0.55, 0.05, 0.60);
        starB = vec3(0.05, 0.10, 0.45); ground = vec3(0.02, 0.02, 0.05);
    } else {
        band = band_color; edge = outline_color; starA = star_color; starB = star_color_b; ground = ground_color;
    }
}

vec3 pick3(vec3 a, vec3 b, vec3 c, float k) {
    k = mod(k, 3.0);
    return k < 0.5 ? a : (k < 1.5 ? b : c);
}

// The colours of one girih field g (from girih()).
vec3 shadeGirih(vec4 g, vec2 tid, vec2 vid, vec2 pm, float pxT, float bw, float ow, float t,
                vec3 band, vec3 edge, vec3 starA, vec3 starB, vec3 ground) {
    // fills: the star of the tile or the shape around the vertex, with echo lines inside the star
    float inStar = 1.0 - smoothstep(-pxT, pxT, g.y);
    vec3 starCol = g.w > 0.5 ? starB : starA;
    float hT = hash12(floor(tid * 4.0 + 0.5) + float(seed) * 7.1);
    float hV = hash12(vid + float(seed) * 5.3);
    float vary = glaze * 0.18;
    vec3 fillStar = starCol * (1.0 - vary + 2.0 * vary * hT);
    vec3 fillGround = ground * (1.0 - vary + 2.0 * vary * hV);
    vec3 col = mix(fillGround, fillStar, inStar);
    if (echo_lines > 0) {
        float spacing = (bw * 2.0 + ow) * 1.1;
        float e = -g.y - bw;                       // inside the star, from the band inwards
        float idx = floor(e / spacing);
        float fe = abs(e - (idx + 0.5) * spacing);
        float line = (1.0 - smoothstep(0.35 * ow + 0.5 * pxT, 0.35 * ow + 1.5 * pxT, fe))
                   * step(0.0, idx) * step(idx, float(echo_lines) - 1.0) * inStar;
        col = mix(col, mix(starCol, band, 0.55), line);
    }
    // gloss: a soft light across each tile
    vec2 lq = pm - mix(vid / 8.0, tid, inStar);
    col *= 1.0 + glaze * 0.3 * (0.35 - length(lq - vec2(-0.12, 0.15)));

    // the bands with their edges, a ridge of light along the middle, the beat
    float d = g.x;
    float pulse = beat_pulse * exp(-5.0 * fract(t));
    vec3 bandCol = band * (1.0 + 0.6 * pulse) * (0.85 + 0.15 * (1.0 - (d / bw) * (d / bw)));
    bandCol *= g.z;
    float inBand = 1.0 - smoothstep(bw - pxT, bw + pxT, d);
    float inEdge = 1.0 - smoothstep(bw + ow - pxT, bw + ow + pxT, d);
    col = mix(col, edge, inEdge);
    return mix(col, bandCol, inBand);
}

// The colour of the carpet at wall position wp (wall units), px = one sample in wall units.
vec3 carpetColor(vec2 wp, float px, float t) {
    vec2 pw = warpDomain(wp, t);
    vec2 p = pw * scale * 0.5;               // tiles
    float pxT = px * scale * 0.5;
    float th = contact_angle + angle_breath * sin(TAU * loopPhase(t))
             + beat_twist * exp(-4.0 * fract(t));
    float theta = radians(clamp(th, 2.0, 89.0));
    float bw = 0.5 * max(strap_width, pxT);  // never thinner than one LED
    float ow = max(outline_width, 0.0);
    float gap = max(ow, 0.6 * pxT);

    vec3 band, edge, starA, starB, ground;
    paletteColors(band, edge, starA, starB, ground);
    if (color_swap_every > 0) {
        // the three fill colours change places every color_swap_every beats, with a one-beat cross-fade
        float e = float(color_swap_every);
        float k = mod(floor(t / e), 3.0);
        float f = smoothstep(0.0, 1.0, fract(t / e) * e);
        vec3 c0 = starA, c1 = starB, c2 = ground;
        starA = mix(pick3(c0, c1, c2, k + 2.0), pick3(c0, c1, c2, k), f);
        starB = mix(pick3(c0, c1, c2, k + 3.0), pick3(c0, c1, c2, k + 1.0), f);
        ground = mix(pick3(c0, c1, c2, k + 4.0), pick3(c0, c1, c2, k + 2.0), f);
    }

    vec2 tidA, vidA;
    vec2 pA = moveCarpet(p, t, (tiling == 1 || tiling == 3 ? HEX_PERIOD : vec2(1.0)) * 256.0);
    vec4 A = girih(pA, tiling, theta, bw, gap, tidA, vidA);
    vec3 col = shadeGirih(A, tidA, vidA, pA, pxT, bw, ow, t, band, edge, starA, starB, ground);
    float m = morphWeight(t);
    if (m > 0.0) {
        // the morph flips tile by tile: each tile of the second tiling at its own moment, from the middle outwards
        vec2 tidB, vidB;
        vec2 pB = moveCarpet(p, t, (tiling_b == 1 || tiling_b == 3 ? HEX_PERIOD : vec2(1.0)) * 256.0);
        vec4 B = girih(pB, tiling_b, theta, bw, gap, tidB, vidB);
        vec2 tileHome = p - (pB - tidB);
        float reach = scale * 0.5 * max(screenAspect(), 1.0) * float(max(wall_columns, wall_rows));
        float thr = 0.82 * mix(hash12(floor(tidB * 4.0 + 0.5) + 11.0), clamp(length(tileHome) / reach, 0.0, 1.0), 0.6);
        float w = smoothstep(thr, thr + 0.16, m);
        if (w > 0.0)
            col = mix(col, shadeGirih(B, tidB, vidB, pB, pxT, bw, ow, t, band, edge, starA, starB, ground), w);
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
