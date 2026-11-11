//@settings dtype=float32 format=rgba
// --- SlitScan: every row, column, ring or brightness of the picture shows another moment (time displacement) ---
// lib/common.glsl says how the frames are kept. Rows: the top is now and the further down, the longer ago (the classic
// slit-scan smear of moving things); Slit stack: the slit-scan camera, one axis of the picture is time.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D C;
uniform sampler2D F;
uniform sampler2D N;
uniform sampler2D S;
uniform sampler2D time_map;

//@slider min=0.0 max=1.0 value=1.0
uniform float depth;                // how much of the history the displacement spans (1 = all of it)
//@slider min=0.0 max=1.0 value=0.0
uniform float offset;               // a delay everywhere, in parts of the history
//@button
uniform bool reverse;               // swaps now and long ago (Rows: the bottom is now)
//@slider min=0.0 max=360.0 value=30.0
uniform float angle;                // Diagonal: degrees, the direction in which the delay grows
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 center;                // Radial: the middle
//@int min=0 max=64 value=0
uniform int steps;                  // > 0: the delay in that many bands (time slices) instead of smooth
//@button value=1
uniform bool smooth_frames;         // blends between two frames instead of jumping from one to the next
//@slider min=0.0 max=1.0 value=0.0
uniform float wobble;               // the bands bend in a slow wave, so the slices are not straight
//@slider min=0.0 max=1.0 value=0.25
uniform float bass_depth;           // the bass (or the kick of the beat) stretches the time further
//@slider min=0.0 max=1.0 value=0.0
uniform float beat_scratch;         // on the beat the time jumps back by this much and runs forward again
//@slider min=0.0 max=1.0 value=1.0
uniform float amount;               // mixes back to the input

// One frame of the cache at uv, bilinear inside its tile. age 0 = the newest
vec4 cacheFrame(int age, ivec4 st, vec2 uv) {
    int g = gridSize();
    int n = g * g;
    int index = ((st.x - age) % n + n) % n;
    ivec2 tileSize = ATLAS / g;
    ivec2 origin = ivec2(index % g, index / g) * tileSize;
    vec2 p = uv * vec2(tileSize) - 0.5;
    ivec2 i0 = ivec2(floor(p));
    vec2 f = p - floor(p);
    ivec2 hi = tileSize - 1;
    vec4 a = texelFetch(C, origin + clamp(i0, ivec2(0), hi), 0);
    vec4 b = texelFetch(C, origin + clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(C, origin + clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(C, origin + clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The input at a delay, in frames of the cache (fractions blend two frames); below one frame the live input shows
vec4 delayed(float age, ivec4 st, vec2 uv, vec4 live) {
    float maxAge = float(max(st.z - 1, 0));
    age = clamp(age, 0.0, maxAge);
    if (!smooth_frames)
        age = floor(age + 0.5);
    int a0 = int(floor(age));
    float f = age - float(a0);
    vec4 c0 = a0 == 0 ? live : cacheFrame(a0, st, uv);
    if (f <= 0.0)
        return c0;
    return mix(c0, cacheFrame(a0 + 1, st, uv), f);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 live = texture(input, uv);
    if (time_mode == 6) {
        fragColor = mix(live, texelFetch(F, ivec2(fragCoord), 0), amount);
        return;
    }
    ivec4 st = readState(C);
    float span = float(gridSize() * gridSize() - 1);
    vec4 lv = musicLevels(S);
    vec4 hit = musicHit(S);
    float scratch = beat_scratch * exp(-hit.y * 3.0);

    vec2 aspect = vec2(iResolution.x / iResolution.y, 1.0);
    vec2 w = uv;
    if (wobble > 0.0) {
        float t = iTime * 0.25;
        w += wobble * 0.08 * vec2(sin(uv.y * 7.0 + t * 3.1) + 0.5 * sin(uv.y * 17.0 - t * 4.3),
                                  sin(uv.x * 5.0 - t * 2.3) + 0.5 * sin(uv.x * 13.0 + t * 3.7));
    }
    float d;
    if (time_mode == 0) {
        d = 1.0 - w.y;
    } else if (time_mode == 1) {
        d = w.x;
    } else if (time_mode == 2) {
        float a = radians(angle);
        vec2 dir = vec2(cos(a), sin(a));
        float lo = min(0.0, dir.x) + min(0.0, dir.y);
        float hi = max(0.0, dir.x) + max(0.0, dir.y);
        d = (dot(w, dir) - lo) / max(hi - lo, 1e-4);
    } else if (time_mode == 3) {
        d = clamp(length((w - center) * aspect) / (0.5 * length(aspect)), 0.0, 1.0);
    } else if (time_mode == 5 && texelFetch(N, ivec2(0), 0).r > 0.5) {
        d = lumaOf(texture(time_map, uv).rgb);
    } else {
        // Brightness, and Time map while nothing is linked into it
        d = lumaOf(live.rgb);
    }
    d = clamp(d, 0.0, 1.0);
    if (reverse)
        d = 1.0 - d;
    if (steps > 0)
        d = floor(d * float(steps)) / max(float(steps) - 1.0, 1.0);
    float age = clamp(offset + scratch + d * depth * (1.0 + bass_depth * lv.x), 0.0, 1.0) * span;
    vec4 col = delayed(age, st, uv, live);
    fragColor = mix(live, col, amount);
}
