//@settings dtype=float32 format=rgba
// --- Spectrum: the frequencies of the sound as bars, blocks or a curve (the Audio Spectrum CHOP drawn as a TOP) ---
// Low frequencies on the left (or in the middle with Mirror), high ones on the right. Layout Bottom, Center (both
// ways from the middle), Top and bottom, or Circle (around the middle). Pass S keeps a level and a falling peak cap per
// bar. Without an audio analysis the Test signal plays a made-up beat.
#include lib/common.glsl

uniform sampler2D S;

//@enum options=(Bottom, Center, Top and bottom, Circle) value=0
uniform int layout_mode;            // where the bars stand
//@enum options=(Bars, Blocks, Curve) value=0
uniform int style;                  // Blocks: an LED meter. Curve: a smooth filled line through the bars
//@button value=0
uniform bool mirror;                // low frequencies in the middle, mirrored to both sides
//@slider min=0.0 max=0.9 value=0.25
uniform float gap;                  // space between the bars
//@slider min=0.05 max=1.0 value=0.7
uniform float height;               // how high a full bar reaches, part of the picture
//@slider min=0.0 max=0.5 value=0.12
uniform float baseline;             // Bottom: where the bars stand. Center: how far apart the two halves are
//@slider min=0.0 max=1.0 value=0.3
uniform float reflection;           // Bottom: a fading mirror image below the baseline
//@int min=4 max=64 value=20
uniform int block_count;            // Blocks: blocks in a full bar
//@slider min=0.05 max=0.6 value=0.22
uniform float inner_radius;         // Circle: where the bars start, part of the picture height
//@slider min=-1.0 max=1.0 value=0.0
uniform float spin;                 // Circle: turns per 4 beats
//@enum options=(Low to high, By height, Rainbow, Single color) value=0
uniform int color_mode;
//@rgb value=(0.1, 0.45, 1.0)
uniform vec3 low_color;             // the colour of the low end (By height: of the bottom)
//@rgb value=(1.0, 0.25, 0.6)
uniform vec3 high_color;            // the colour of the high end (By height: of the top)
//@rgb value=(1.0, 1.0, 1.0)
uniform vec3 peak_color;            // the colour of the peak caps
//@slider min=0.0 max=2.0 value=0.6
uniform float glow;                 // a soft light around the bars
//@slider min=0.0 max=1.0 value=0.25
uniform float beat_flash;           // brighter at every beat
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;

vec4 bar(int i) {
    return texelFetch(S, ivec2(clamp(i, 0, clamp(bar_count, 2, 128) - 1), 0), 0);
}

// The level (ch 0) or the peak (ch 1) of the curve at u (0 .. 1 across): Catmull-Rom through the bars
float curveLevel(float u, int n, int ch) {
    float f = u * float(n) - 0.5;
    int i = int(floor(f));
    float t = f - float(i);
    float p0 = bar(i - 1)[ch], p1 = bar(i)[ch], p2 = bar(i + 1)[ch], p3 = bar(i + 2)[ch];
    float t2 = t * t, t3 = t2 * t;
    float v = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
            + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
    return max(v, 0.0);
}

vec3 hue(float h) {
    return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

vec3 barColor(float u, float d) {
    if (color_mode == 1)
        return mix(low_color, high_color, clamp(d, 0.0, 1.0));
    if (color_mode == 2)
        return hue(u * 0.85 + iTime * 0.05);
    if (color_mode == 3)
        return low_color;
    return mix(low_color, high_color, u);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    int n = clamp(bar_count, 2, 128);

    // u: 0 .. 1 across the bars, d: the distance from where the bars stand, in full bar heights;
    // du, dd: one pixel in these units
    float u, d, du, dd;
    float refl = 1.0;
    if (layout_mode == 3) {
        vec2 p = (fragCoord - 0.5 * res) / res.y;
        float r = length(p);
        float a = atan(p.x, -p.y) / AUDIO_TAU + 0.5;         // 0 and 1 at the top
        u = fract(a + iTime * spin * 0.25);
        d = (r - inner_radius) / max(height * 0.5, 0.01);
        du = 1.0 / max(AUDIO_TAU * r * res.y, 1.0);
        dd = 1.0 / (max(height * 0.5, 0.01) * res.y);
    } else {
        u = uv.x;
        du = 1.0 / res.x;
        dd = 1.0 / (max(height, 0.01) * res.y);
        if (layout_mode == 1) {
            d = (abs(uv.y - 0.5) - baseline * 0.5) / max(height * 0.5, 0.01);
            dd *= 2.0;
        } else if (layout_mode == 2) {
            d = min(uv.y, 1.0 - uv.y) / max(height * 0.5, 0.01);
            dd *= 2.0;
        } else {
            d = (uv.y - baseline) / max(height, 0.01);
            if (d < 0.0) {
                refl = reflection * (1.0 - smoothstep(0.0, 0.4, -d)) * 0.5;
                d = -d;
            }
        }
    }
    if (mirror) {
        u = abs(u * 2.0 - 1.0);
        du *= 2.0;
    }

    float fi = u * float(n);
    int i = int(floor(min(fi, float(n) - 0.001)));
    float f = fi - float(i);
    float aa = du * float(n);                                // one pixel, in bar widths

    vec4 b = bar(i);
    float level = b.r, peak = b.g;
    float flash = 1.0 + beat_flash * exp(-fract(iTime) * 5.0);

    vec3 col = background;
    float fill = 0.0, cap = 0.0, glw = 0.0;
    float above = step(0.0, d);

    if (style == 2) {
        // Curve: filled below the line, a bright edge on it
        float c = curveLevel(u, n, 0);
        float slope = abs(curveLevel(min(u + du, 1.0), n, 0) - c) / max(du, 1e-6) * (du / dd);
        float w = dd * (1.2 + 0.5 * sqrt(1.0 + slope * slope));
        float body = (1.0 - smoothstep(c - dd, c + dd, d)) * above;
        float edge = 1.0 - smoothstep(w * 0.5, w, abs(d - c));
        fill = body * 0.45 * (0.4 + 0.6 * d / max(c, 0.001)) + edge;
        if (peak_hold > 0.0) {
            float pc = curveLevel(u, n, 1);
            cap = (1.0 - smoothstep(dd, 2.0 * dd, abs(d - pc - 2.0 * dd))) * 0.6 * above;
        }
        glw = exp(-max(d - c, 0.0) * 6.0) * above * (1.0 - body) * 0.6;
    } else {
        float half_w = 0.5 * (1.0 - gap);
        float inside_x = 1.0 - smoothstep(half_w - aa * 0.5, half_w + aa * 0.5, abs(f - 0.5));
        float inside_y;
        if (style == 1) {
            // Blocks: a block is lit when the level reaches its middle
            float segs = float(clamp(block_count, 4, 64));
            float k = floor(d * segs);
            float sf = d * segs - k;
            float shape = smoothstep(0.0, dd * segs, sf) * (1.0 - smoothstep(0.72 - dd * segs, 0.72, sf));
            inside_y = shape * step(k + 0.5, level * segs) * above * step(d, 1.0);
        } else {
            inside_y = (1.0 - smoothstep(level - dd * 0.5, level + dd * 0.5, d)) * smoothstep(-dd * 0.5, dd * 0.5, d);
        }
        fill = inside_x * inside_y;
        if (peak_hold > 0.0) {
            float ch = max(dd * 3.0, 0.012);
            cap = inside_x * (1.0 - smoothstep(ch * 0.5, ch * 0.5 + dd, abs(d - peak - ch))) * above;
        }
        // glow: above the bar in its column, and into the gaps
        float gx = exp(-max(abs(f - 0.5) - half_w, 0.0) * 6.0);
        glw = gx * exp(-max(d - level, 0.0) * 5.0) * above * smoothstep(0.0, 0.08, level) * 0.6 * (1.0 - fill);
    }

    vec3 c = barColor(style == 2 ? u : (float(i) + 0.5) / float(n), d) * flash;
    col += c * fill * refl;
    col += peak_color * cap * refl * flash;
    col += c * glw * glow * refl;

    fragColor = vec4(col, 1.0);
}
