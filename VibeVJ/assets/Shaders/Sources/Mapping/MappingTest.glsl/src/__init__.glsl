//@settings dtype=float32 format=rgba
// --- MappingTest (#586, projection mapping building blocks) ---
// Test and calibration patterns for setting up projectors: a grid with major lines, circles (a circle that is not
// round on the wall shows a wrong aspect or warp), a checkerboard, colour bars, grey ramps, a solid colour, and the
// mask on its own to check that it sits on the object. On top: crosshair, diagonals, a frame on the very edge of the
// picture, the number of the projector, the overlap zones of edge blending, a square that flashes on the beat and a
// bar that steps with it (to compare the timing of two projectors). One pass.
#define MASK_AUTO 2
#include lib/mapping.glsl
#include lib/mask.glsl

//@enum options=(Grid, Grid and circles, Checkerboard, Colour bars, Grey ramps, Solid colour, Mask check) value=1
uniform int pattern;
//@slider min=8.0 max=400.0 value=60.0
uniform float grid_spacing;     // pixels between two lines (squares of the checkerboard)
//@int min=1 max=16 value=4
uniform int major_every;        // every this many lines a brighter one; the middle lines are always major
//@slider min=0.5 max=8.0 value=1.0
uniform float line_width;       // pixels
//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 line_color;
//@rgb value=(0.5, 0.5, 0.5)
uniform vec3 solid_color;       // Solid colour
//@button value=1
uniform bool crosshair;
//@button
uniform bool diagonals;
//@button value=1
uniform bool frame;             // a line on the outermost pixels of the picture
//@int min=0 max=99 value=1
uniform int projector_id;       // the big number in the middle; 0: none
//@slider min=0.0 max=800.0 value=0.0
uniform float blend_left;       // pixels: the overlap with the next projector, shown hatched with its ramp
//@slider min=0.0 max=800.0 value=0.0
uniform float blend_right;
//@slider min=0.0 max=800.0 value=0.0
uniform float blend_top;
//@slider min=0.0 max=800.0 value=0.0
uniform float blend_bottom;
//@button value=1
uniform bool beat_square;       // a square at the top left that flashes on every beat
//@button
uniform bool beat_bar;          // a bar that moves one grid cell per beat
//@slider min=0.0 max=1.0 value=0.0
uniform float mask_overlay;     // the outline and inside of the mask over the pattern
//@slider min=0.0 max=1.0 value=1.0
uniform float brightness;

float line_px(float x, float w) {
    return 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.5, abs(x));
}

// distance-like lines of a grid through the middle: p in pixels from the middle; returns (minor, major)
vec2 grid(vec2 p, float sp, float w) {
    vec2 k = p / sp;
    vec2 f = (k - floor(k + 0.5)) * sp;
    float minor = max(line_px(f.x, w), line_px(f.y, w));
    float n = float(max(major_every, 1)) * sp;
    vec2 g = (p / n - floor(p / n + 0.5)) * n;
    float major = max(line_px(g.x, w * 2.0), line_px(g.y, w * 2.0));
    return vec2(minor, major);
}

// a seven segment digit in a box of 0.6 x 1 (q from its middle, units of its height)
float digit(vec2 q, int dgt) {
    int bits[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int b = bits[clamp(dgt, 0, 9)];
    float t = 0.07;
    float d = 1e5;
    // a: top, b: top right, c: bottom right, d: bottom, e: bottom left, f: top left, g: middle
    if ((b & 1) != 0) d = min(d, mp_sd_box(q - vec2(0.0, 0.45), vec2(0.22, t), t));
    if ((b & 2) != 0) d = min(d, mp_sd_box(q - vec2(0.25, 0.22), vec2(t, 0.2), t));
    if ((b & 4) != 0) d = min(d, mp_sd_box(q - vec2(0.25, -0.22), vec2(t, 0.2), t));
    if ((b & 8) != 0) d = min(d, mp_sd_box(q - vec2(0.0, -0.45), vec2(0.22, t), t));
    if ((b & 16) != 0) d = min(d, mp_sd_box(q - vec2(-0.25, -0.22), vec2(t, 0.2), t));
    if ((b & 32) != 0) d = min(d, mp_sd_box(q - vec2(-0.25, 0.22), vec2(t, 0.2), t));
    if ((b & 64) != 0) d = min(d, mp_sd_box(q, vec2(0.22, t), t));
    return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    vec2 p = fragCoord - res * 0.5;
    float w = max(line_width, 0.5);
    vec3 rgb = vec3(0.0);

    if (pattern == 0 || pattern == 1) {
        vec2 g = grid(p, max(grid_spacing, 4.0), w);
        rgb = line_color * (g.x * 0.45 + g.y * 0.55);
        if (pattern == 1) {
            float r = length(p);
            float sp = max(grid_spacing, 4.0) * 2.0;
            float ring = line_px(r - sp * floor(r / sp + 0.5), w);
            float big = line_px(r - min(res.x, res.y) * 0.5 + w, w * 2.0);
            rgb = max(rgb, line_color * max(ring * 0.5, big));
        }
    } else if (pattern == 2) {
        vec2 k = floor(p / max(grid_spacing, 4.0));
        rgb = vec3(mod(k.x + k.y, 2.0));
    } else if (pattern == 3) {
        int i = int(floor(uv.x * 8.0));
        vec3 bars[8] = vec3[8](vec3(1.0), vec3(1.0, 1.0, 0.0), vec3(0.0, 1.0, 1.0), vec3(0.0, 1.0, 0.0),
                               vec3(1.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0));
        rgb = bars[clamp(i, 0, 7)] * 0.75;
        if (uv.y < 0.2) rgb = vec3(floor(uv.x * 16.0) / 15.0);
    } else if (pattern == 4) {
        // top: 16 steps, middle: a smooth ramp, bottom: the darkest steps (0..10 %) to see where black ends
        if (uv.y > 0.66) rgb = vec3(floor(uv.x * 16.0) / 15.0);
        else if (uv.y > 0.33) rgb = vec3(uv.x);
        else rgb = vec3(floor(uv.x * 11.0) / 100.0);
    } else if (pattern == 5) {
        rgb = solid_color;
    }

    float m = 0.0;
    if (pattern == 6 || mask_overlay > 0.0) m = mp_mask(uv);
    if (pattern == 6) {
        float hatch = line_px(mod(p.x + p.y, 24.0) - 12.0, 2.0);
        float edge = clamp(1.0 - abs(m - 0.5) * 2.0 / max(fwidth(m) * 2.0, 1e-3), 0.0, 1.0);
        rgb = line_color * (m * (0.25 + 0.5 * hatch)) + vec3(1.0, 0.85, 0.1) * edge;
    }

    if (crosshair) {
        float c = max(line_px(p.x, w * 2.0), line_px(p.y, w * 2.0)) * step(abs(p.x) + abs(p.y), min(res.x, res.y) * 0.25);
        c = max(c, line_px(length(p) - min(res.x, res.y) * 0.08, w * 2.0));
        rgb = max(rgb, vec3(1.0, 0.25, 0.2) * c);
    }
    if (diagonals) {
        vec2 dg = normalize(res);
        float d1 = abs(dot(p, vec2(-dg.y, dg.x)));
        float d2 = abs(dot(p, vec2(dg.y, dg.x)));
        rgb = max(rgb, line_color * 0.7 * max(line_px(d1, w), line_px(d2, w)));
    }
    if (frame) {
        vec2 e = min(fragCoord, res - fragCoord);
        rgb = max(rgb, vec3(0.2, 1.0, 0.3) * (1.0 - smoothstep(w * 2.0, w * 2.0 + 1.0, min(e.x, e.y))));
    }
    if (projector_id > 0) {
        float hgt = res.y * 0.16;
        vec2 q = (p - vec2(0.0, -res.y * 0.25)) / hgt;
        int tens = projector_id / 10;
        float dd = tens > 0 ? min(digit(q + vec2(0.4, 0.0), tens), digit(q - vec2(0.4, 0.0), projector_id % 10)) : digit(q, projector_id);
        float ink = 1.0 - smoothstep(-1.0 / hgt, 1.0 / hgt, dd);
        float halo = 1.0 - smoothstep(0.0, 0.08, dd);
        rgb = mix(rgb * (1.0 - halo), vec3(1.0, 0.85, 0.2), ink);
    }

    // the overlap zones of edge blending: hatched, with the ramp the other projector fades with
    float zl = blend_left > 0.0 ? clamp(1.0 - fragCoord.x / blend_left, 0.0, 1.0) : 0.0;
    float zr = blend_right > 0.0 ? clamp(1.0 - (res.x - fragCoord.x) / blend_right, 0.0, 1.0) : 0.0;
    float zb = blend_bottom > 0.0 ? clamp(1.0 - fragCoord.y / blend_bottom, 0.0, 1.0) : 0.0;
    float zt = blend_top > 0.0 ? clamp(1.0 - (res.y - fragCoord.y) / blend_top, 0.0, 1.0) : 0.0;
    float z = max(max(zl, zr), max(zb, zt));
    if (z > 0.0) {
        float hatch = line_px(mod(p.x - p.y, 16.0) - 8.0, 1.5);
        rgb = mix(rgb, vec3(0.2, 0.5, 1.0) * (0.3 + 0.7 * hatch), 0.5);
        float zone_edge = max(max(line_px(fragCoord.x - blend_left, w * 2.0) * step(0.001, blend_left),
                                  line_px(res.x - fragCoord.x - blend_right, w * 2.0) * step(0.001, blend_right)),
                              max(line_px(fragCoord.y - blend_bottom, w * 2.0) * step(0.001, blend_bottom),
                                  line_px(res.y - fragCoord.y - blend_top, w * 2.0) * step(0.001, blend_top)));
        rgb = max(rgb, vec3(0.3, 0.7, 1.0) * zone_edge);
    }

    float beat = 1.0 - fract(iTime);
    if (beat_square) {
        float s = min(res.x, res.y) * 0.08;
        vec2 bq = fragCoord - vec2(s * 0.5, res.y - s * 0.5) - vec2(s * 0.3, -s * 0.3);
        float inside = 1.0 - step(s * 0.5, max(abs(bq.x), abs(bq.y)));
        rgb = mix(rgb, vec3(pow(beat, 3.0)), inside);
    }
    if (beat_bar) {
        float sp = max(grid_spacing, 4.0);
        float cells = floor(res.x / sp);
        float x = (mod(floor(iTime), max(cells, 1.0)) + 0.5) * sp;
        rgb = max(rgb, vec3(1.0, 0.3, 0.9) * (1.0 - step(sp * 0.25, abs(fragCoord.x - x))) * step(res.y * 0.45, fragCoord.y) * step(fragCoord.y, res.y * 0.55));
    }
    if (mask_overlay > 0.0 && pattern != 6) {
        float edge = clamp(1.0 - abs(m - 0.5) * 2.0 / max(fwidth(m) * 2.0, 1e-3), 0.0, 1.0);
        rgb = mix(rgb, vec3(1.0, 0.1, 0.1), mask_overlay * (0.3 * m));
        rgb = max(rgb, vec3(1.0, 0.85, 0.1) * edge * mask_overlay);
    }
    fragColor = vec4(rgb * brightness, 1.0);
}
