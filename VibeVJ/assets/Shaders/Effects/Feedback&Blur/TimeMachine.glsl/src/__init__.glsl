// --- TimeMachine: a frame cache with time displacement (the Cache + Time Machine TOPs of TouchDesigner) ---
// Every pixel shows the input from a moment ago: the same delay everywhere, a delay that grows across the picture
// (slit scan), from the middle out, by the brightness of a second picture (port Time map), by a moving noise, or
// several delayed copies on top of each other (echo). lib/common.glsl says how the frames are kept.
#include lib/common.glsl

uniform sampler2D input;
uniform sampler2D Cache;
// Its brightness is the delay of each pixel (Time mode Map input): black = now, white = the oldest frame
uniform sampler2D time_map;

//@enum options=(Delay, Slit scan, Radial, Map input, Noise, Echo) value=1
uniform int time_mode;
//@slider min=0.0 max=1.0 value=0.0
uniform float offset;               // the delay everywhere, in parts of the cache (1 = the oldest frame)
//@slider min=0.0 max=1.0 value=1.0
uniform float depth;                // how much of the cache the displacement spans
//@slider min=0.0 max=360.0 value=0.0
uniform float slit_angle;           // Slit scan: degrees, the direction in which the delay grows
//@slidervec2 min=(0.0,0.0) max=(1.0,1.0) value=(0.5,0.5)
uniform vec2 center;                // Radial: the middle
//@button
uniform bool invert;                // swaps now and long ago
//@int min=0 max=64 value=0
uniform int steps;                  // > 0: the delay in that many bands (time slices) instead of smooth
//@slider min=0.5 max=10.0 value=2.0
uniform float noise_scale;
//@slider min=0.0 max=2.0 value=0.25
uniform float noise_speed;          // per beat
//@int min=2 max=8 value=4
uniform int echo_count;
//@slider min=0.0 max=0.5 value=0.12
uniform float echo_spacing;         // parts of the cache between two copies
//@slider min=0.0 max=1.0 value=0.65
uniform float echo_decay;           // each older copy is this much as bright
//@slider min=0.0 max=1.0 value=0.0
uniform float beat_scratch;         // at every beat the delay jumps back by this much and runs forward again
//@slider min=1.0 max=12.0 value=3.0
uniform float scratch_decay;
//@button value=1
uniform bool smooth_frames;         // blends between two frames instead of jumping from one to the next
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
    vec4 a = texelFetch(Cache, origin + clamp(i0, ivec2(0), hi), 0);
    vec4 b = texelFetch(Cache, origin + clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0);
    vec4 c = texelFetch(Cache, origin + clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0);
    vec4 d = texelFetch(Cache, origin + clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0);
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
    ivec4 st = readState(Cache);
    float span = float(gridSize() * gridSize() - 1);
    float scratch = beat_scratch * pow(1.0 - fract(iTime), scratch_decay);

    if (time_mode == 5) {
        vec4 sum = live;
        float wsum = 1.0;
        float w = 1.0;
        for (int k = 1; k < 8; k++) {
            if (k >= echo_count)
                break;
            w *= echo_decay;
            float age = (offset + scratch + float(k) * echo_spacing) * span;
            sum += w * delayed(age, st, uv, live);
            wsum += w;
        }
        fragColor = mix(live, sum / wsum, amount);
        return;
    }

    vec2 aspect = vec2(iResolution.x / iResolution.y, 1.0);
    float d = 0.0;
    if (time_mode == 1) {
        float a = radians(slit_angle);
        vec2 dir = vec2(cos(a), sin(a));
        // 0 .. 1 across the picture along dir
        float lo = min(0.0, dir.x) + min(0.0, dir.y);
        float hi = max(0.0, dir.x) + max(0.0, dir.y);
        d = (dot(uv, dir) - lo) / max(hi - lo, 1e-4);
    } else if (time_mode == 2) {
        d = clamp(length((uv - center) * aspect) / (0.5 * length(aspect)), 0.0, 1.0);
    } else if (time_mode == 3) {
        d = luminance(texture(time_map, uv).rgb);
    } else if (time_mode == 4) {
        vec2 p = (uv - 0.5) * aspect * noise_scale;
        d = clamp(0.5 + 0.9 * gradientNoise(vec3(p, iTime * noise_speed)), 0.0, 1.0);
    }
    if (invert)
        d = 1.0 - d;
    if (time_mode == 0)
        d = 0.0;
    if (steps > 0)
        d = floor(d * float(steps)) / max(float(steps) - 1.0, 1.0);
    float age = clamp(offset + scratch + d * depth, 0.0, 1.0) * span;
    fragColor = mix(live, delayed(age, st, uv, live), amount);
}
