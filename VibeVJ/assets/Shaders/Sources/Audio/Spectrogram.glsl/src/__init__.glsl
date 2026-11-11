//@settings dtype=float32 format=rgba
// --- Spectrogram: the sound over time (the history of the Audio Spectrum CHOP as a TOP) ---
// Pass H keeps the last 256 frames of the spectrum (or the waveform). View Waterfall: frequency across, time along,
// coloured by a palette. Ridgeline: a stack of lines in depth, the newest in front, each hiding the ones behind it
// (the cover of Unknown Pleasures). Circle: frequency around, time outwards. Raw: the level as grey, a map for other
// effects (Displace, GradientMap, InstanceGrid, the Field of Particles). Without an audio analysis the Test signal
// plays a made-up beat.
#include lib/common.glsl

uniform sampler2D H;

//@enum options=(Waterfall, Ridgeline, Circle, Raw) value=0
uniform int view;
//@enum options=(Up, Down, Left, Right) value=0
uniform int direction;              // Waterfall and Raw: where the history runs to; the newest row starts on the other side
//@int min=16 max=256 value=160
uniform int history;                // how many frames are shown
//@slider min=20.0 max=2000.0 value=30.0
uniform float low_freq;             // Spectrum: the lowest frequency shown, Hz
//@slider min=200.0 max=20000.0 value=16000.0
uniform float high_freq;            // Spectrum: the highest frequency shown, Hz
//@slider min=0.0 max=4.0 value=1.0
uniform float gain;
//@slider min=0.3 max=3.0 value=1.4
uniform float curve;                // above 1: only the loud parts light up
//@enum options=(Heat, Ice, Neon, Mono, Two colors) value=0
uniform int palette;
//@rgb value=(0.1, 0.2, 0.9)
uniform vec3 color_a;               // Two colors: the quiet colour
//@rgb value=(1.0, 0.9, 0.3)
uniform vec3 color_b;               // Two colors: the loud colour
//@int min=8 max=80 value=36
uniform int line_count;             // Ridgeline: how many lines
//@slider min=0.0 max=0.5 value=0.16
uniform float ridge_height;         // Ridgeline: how high a full level lifts a line, part of the picture
//@slider min=0.0 max=1.0 value=0.5
uniform float perspective;          // Ridgeline: lines further back are narrower
//@slider min=0.5 max=8.0 value=2.0
uniform float line_width;           // Ridgeline: pixels of a 1080p picture
//@slider min=0.0 max=0.45 value=0.08
uniform float inner_radius;         // Circle: the newest frame is this ring, part of the picture height
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;

vec3 inferno(float t) {
    const vec3 c0 = vec3(0.0002189403691192265, 0.001651004631001012, -0.01948089843709184);
    const vec3 c1 = vec3(0.1065134194856116, 0.5639564367884091, 3.932712388889277);
    const vec3 c2 = vec3(11.60249308247187, -3.972853965665698, -15.9423941062914);
    const vec3 c3 = vec3(-41.70399613139459, 17.43639888205313, 44.35414519872813);
    const vec3 c4 = vec3(77.162935699427, -33.40235894210092, -81.80730925738993);
    const vec3 c5 = vec3(-71.31942824499214, 32.62606426397723, 73.20951985803202);
    const vec3 c6 = vec3(25.13112622477341, -12.24266895238567, -23.07032500287172);
    return clamp(c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6))))), 0.0, 1.0);
}

vec3 paletteColor(float v) {
    v = clamp(v, 0.0, 1.0);
    if (palette == 1)
        return v < 0.5 ? mix(vec3(0.0), vec3(0.05, 0.3, 0.9), v * 2.0) : mix(vec3(0.05, 0.3, 0.9), vec3(0.85, 1.0, 1.0), v * 2.0 - 1.0);
    if (palette == 2)
        return mix(mix(vec3(0.0), vec3(0.95, 0.1, 0.75), smoothstep(0.0, 0.5, v)), vec3(0.2, 1.0, 1.0), smoothstep(0.45, 1.0, v));
    if (palette == 3)
        return vec3(v);
    if (palette == 4)
        return v < 0.5 ? mix(background, color_a, v * 2.0) : mix(color_a, color_b, v * 2.0 - 1.0);
    return inferno(v);
}

// The x of the history texture for u (0 .. 1 across the shown range)
float columnOf(float u) {
    if (signal == 1)
        return clamp(u, 0.0, 1.0) * 511.0;
    float lo = freqToX(low_freq);
    float hi = max(freqToX(high_freq), lo + 0.01);
    return mix(lo, hi, clamp(u, 0.0, 1.0)) * 511.0;
}

float shape(float v) {
    return pow(clamp(v * gain, 0.0, 1.0), curve);
}

// The level at u (0 .. 1 across) and age (0 = now, 1 = the oldest frame shown), between the texels
float level(float u, float age) {
    float x = columnOf(u);
    float y = clamp(age, 0.0, 1.0) * float(clamp(history, 16, 256) - 1);
    ivec2 i0 = ivec2(floor(vec2(x, y)));
    vec2 f = vec2(x, y) - vec2(i0);
    ivec2 hi = ivec2(511, 255);
    float a = texelFetch(H, clamp(i0, ivec2(0), hi), 0).r;
    float b = texelFetch(H, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0).r;
    float c = texelFetch(H, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0).r;
    float d = texelFetch(H, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0).r;
    return shape(mix(mix(a, b, f.x), mix(c, d, f.x), f.y));
}

// One row (nearest in time, between the texels across): the ridgeline reads many of them
float rowLevel(float u, int row) {
    float x = columnOf(u);
    int i = int(floor(x));
    float f = x - float(i);
    float a = texelFetch(H, ivec2(clamp(i, 0, 511), row), 0).r;
    float b = texelFetch(H, ivec2(clamp(i + 1, 0, 511), row), 0).r;
    return shape(mix(a, b, f));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;

    if (view == 1) {
        // Ridgeline: front to back, the first line the pixel is on or below decides
        int n = clamp(line_count, 8, 80);
        int hist = clamp(history, 16, 256);
        float aspect = res.x / res.y;
        float px = 1.0 / res.y;
        float lw = max(line_width * res.y / 1080.0, 0.75) * px;
        vec2 p = vec2((uv.x - 0.5) * aspect, uv.y);
        vec3 col = background;
        for (int i = 0; i < 80; i++) {
            if (i >= n)
                break;
            float z = float(i) / float(n - 1);
            float base = mix(0.1, 0.78, z);
            float hw = 0.36 * aspect * (1.0 - perspective * 0.55 * z);
            float u = p.x / (2.0 * hw) + 0.5;
            // a line is as wide as its span (narrower further back), so the depth shows
            if (u < -0.02 || u > 1.02)
                continue;
            int row = min(int(z * float(hist - 1)), 255);
            float env = smoothstep(0.0, 0.28, u) * smoothstep(1.0, 0.72, u);
            float v = (u > 0.0 && u < 1.0) ? rowLevel(u, row) * env : 0.0;
            float y = base + ridge_height * (1.0 - 0.4 * perspective * z) * v;
            float dy = abs(p.y - y);
            // the line gets thicker where it is steep: look at the slope
            float v2 = (u > 0.0 && u < 1.0) ? rowLevel(u + px / (2.0 * hw), row) * env : 0.0;
            float slope = ridge_height * (v2 - v) / px;
            float d = dy / sqrt(1.0 + slope * slope);
            if (d < lw * 1.5) {
                float a = 1.0 - smoothstep(lw * 0.5, lw * 1.5, d);
                vec3 lc = paletteColor(0.55 + 0.45 * v) * mix(1.0, 0.5, z);
                if (palette == 3 || palette == 4)
                    lc = (palette == 3 ? vec3(1.0) : color_b) * mix(1.0, 0.5, z);
                col = mix(background, lc, a);
                break;
            }
            if (p.y < y)
                break;
        }
        fragColor = vec4(col, 1.0);
        return;
    }

    float u, age;
    if (view == 2) {
        vec2 p = (fragCoord - 0.5 * res) / res.y;
        float a = fract(atan(p.x, -p.y) / AUDIO_TAU + 0.5);
        u = abs(a * 2.0 - 1.0);                           // low at the bottom, high at the top, both sides
        float outer = 0.5 * res.x / res.y;
        age = (length(p) - inner_radius) / max(outer - inner_radius, 0.01);
        if (age < 0.0) {
            fragColor = vec4(background, 1.0);
            return;
        }
    } else if (direction == 1) {
        u = uv.x;
        age = 1.0 - uv.y;
    } else if (direction == 2) {
        u = uv.y;
        age = 1.0 - uv.x;
    } else if (direction == 3) {
        u = uv.y;
        age = uv.x;
    } else {
        u = uv.x;
        age = uv.y;
    }

    float v = level(u, age) * step(age, 1.0);
    if (view == 3) {
        fragColor = vec4(vec3(v), 1.0);
        return;
    }
    vec3 col = palette == 4 ? paletteColor(v) : mix(background, paletteColor(v), smoothstep(0.0, 0.08, v));
    fragColor = vec4(col, 1.0);
}
