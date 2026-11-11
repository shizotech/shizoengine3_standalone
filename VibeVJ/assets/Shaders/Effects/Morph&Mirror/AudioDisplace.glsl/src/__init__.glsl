//@settings dtype=float32 format=rgba
// --- AudioDisplace: the sound moves the pixels of the input ---
// Mode Wave rows: each row (or column) is pushed sideways by the waveform, a wobble like a hit CRT. Spectrum rings:
// rings around the Center swell with the frequencies, low ones inside, high ones outside. Band slices: the picture
// cut into slices, each pushed by the level of its own frequency band, a glitch that dances. Bass zoom: the bass zooms
// in, the mids turn the picture. Color split pulls red and blue apart with the highs, Flash brightens with the bass.
// Pass E keeps the levels of Low, Mid and High. Without an audio analysis the Test signal plays a made-up beat.
#include lib/common.glsl

// The picture that is moved
uniform sampler2D input;
uniform sampler2D E;

//@enum options=(Wave rows, Spectrum rings, Band slices, Bass zoom) value=0
uniform int mode;
//@slider min=0.0 max=0.3 value=0.05
uniform float amount;               // how far the pixels move, part of the picture height
//@enum options=(Horizontal, Vertical) value=0
uniform int direction;              // Wave rows and Band slices: rows pushed sideways, or columns pushed up and down
//@int min=32 max=512 value=256
uniform int wave_length;            // Wave rows: samples of the waveform across the picture
//@int min=2 max=64 value=12
uniform int slices;                 // Band slices: how many slices (each a part of the spectrum, low to high)
//@slider min=0.0 max=1.0 value=0.3
uniform float ripple;               // Spectrum rings: fine rings that run outwards with the beat
//@slider min=-90.0 max=90.0 value=12.0
uniform float twist;                // Bass zoom: degrees the mids turn the picture
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 center;                // Spectrum rings and Bass zoom: the middle
//@slider min=0.0 max=1.0 value=0.3
uniform float color_split;          // the highs pull red and blue apart
//@slider min=0.0 max=1.0 value=0.15
uniform float flash;                // the bass brightens the picture
//@enum options=(Clamp, Repeat, Mirror) value=2
uniform int edge_mode;              // what is shown where a pixel is taken from outside the picture

vec2 edge(vec2 uv) {
    if (edge_mode == 1)
        return fract(uv);
    if (edge_mode == 2)
        return 1.0 - abs(1.0 - mod(uv, 2.0));
    return clamp(uv, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    float aspect = res.x / res.y;
    vec4 lv = texelFetch(E, ivec2(0), 0);          // low, mid, high, loudest sample

    // the offset in parts of the picture height, x and y alike (x is divided by the aspect at the end)
    vec2 off = vec2(0.0);
    vec2 dir = vec2(0.0);          // the direction the colour split pulls along
    if (mode == 0) {
        float along = direction == 0 ? uv.y : uv.x;
        float w = waveAt(along * float(clamp(wave_length, 32, 512)) * (511.0 / 512.0));
        off = direction == 0 ? vec2(w, 0.0) : vec2(0.0, w);
        off *= amount * 1.5;
        dir = direction == 0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    } else if (mode == 1) {
        vec2 p = (uv - center) * vec2(aspect, 1.0);
        float r = length(p);
        float x = clamp(r / 0.8, 0.0, 1.0);
        float lvl = spectrumAt(mix(freqToX(40.0), freqToX(12000.0), x));
        float rip = 1.0 + ripple * sin(r * 60.0 - fract(iTime) * AUDIO_TAU);
        vec2 n = r > 1e-4 ? p / r : vec2(0.0);
        off = -n * lvl * amount * rip;
        dir = n;
    } else if (mode == 2) {
        int ns = clamp(slices, 2, 64);
        float across = direction == 0 ? uv.y : uv.x;
        float k = min(floor(across * float(ns)), float(ns - 1));
        float lo = freqToX(40.0), hi = freqToX(12000.0);
        float a = mix(lo, hi, k / float(ns)), b = mix(lo, hi, (k + 1.0) / float(ns));
        // the mean of 8 points of its band: 8 reads a pixel, not up to 48
        float lvl = 0.0;
        for (int j = 0; j < 8; j++)
            lvl += spectrumAt(mix(a, b, (float(j) + 0.5) / 8.0));
        lvl /= 8.0;
        float side = mod(k, 2.0) < 1.0 ? 1.0 : -1.0;
        off = (direction == 0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0)) * lvl * amount * 2.0 * side;
        dir = direction == 0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    } else {
        vec2 p = (uv - center) * vec2(aspect, 1.0);
        float zoom = 1.0 + lv.r * amount * 4.0;
        float ang = radians(twist) * lv.g;
        mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
        vec2 q = rot * p / zoom;
        off = q - p;
        dir = length(p) > 1e-4 ? normalize(p) : vec2(0.0);
    }

    vec2 to_uv = vec2(1.0 / aspect, 1.0);
    vec2 base = uv - off * to_uv;
    vec2 split = dir * color_split * lv.b * 0.02 * to_uv;
    vec3 col;
    col.r = texture(input, edge(base + split)).r;
    col.g = texture(input, edge(base)).g;
    col.b = texture(input, edge(base - split)).b;
    float alpha = texture(input, edge(base)).a;
    col *= 1.0 + flash * lv.r * lv.r * 1.5;
    fragColor = vec4(col, alpha);
}
