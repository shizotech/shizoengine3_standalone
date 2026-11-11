//@settings dtype=float32 format=rgba
// --- Oscilloscope: the waveform of the sound as a glowing line with phosphor trails ---
// Mode Line (left to right), Mirror (the wave and its mirror image), Filled (filled to the middle, like a sound
// editor) or Circle (the wave around a ring). Trigger Rising edge holds a steady tone still, like a real scope (pass T).
// The trails are the last frames, faded by Trail and zoomed, turned and coloured a bit every frame: tunnels and
// spirals out of the sound. Without an audio analysis the Test signal plays a made-up beat.
#include lib/common.glsl

uniform sampler2D T;
uniform sampler2D feedback;

//@enum options=(Line, Mirror, Filled, Circle) value=0
uniform int mode;
//@slider min=0.5 max=24.0 value=3.0
uniform float thickness;            // the width of the line, pixels of a 1080p picture
//@slider min=0.05 max=1.0 value=0.6
uniform float size;                 // how tall a full wave is, part of the picture height (Circle: how far it swings)
//@slider min=0.05 max=0.6 value=0.28
uniform float radius;               // Circle: the radius of the ring, part of the picture height
//@slidervec2 min=(-0.5,-0.5) max=(0.5,0.5) value=(0.0,0.0)
uniform vec2 position;              // moves the wave from the middle
//@rgb value=(0.3, 1.0, 0.55)
uniform vec3 line_color;
//@slider min=0.0 max=1.0 value=0.0
uniform float rainbow;              // the colour runs through the hues along the line
//@slider min=0.0 max=3.0 value=1.0
uniform float glow;                 // light around the line
//@slider min=1.0 max=60.0 value=14.0
uniform float glow_size;            // how far the glow reaches, pixels of a 1080p picture
//@slider min=0.0 max=0.99 value=0.82
uniform float trail;                // how long the last frames stay (phosphor); 0 = no trails
//@slider min=-0.05 max=0.05 value=0.006
uniform float trail_zoom;           // the trails grow (> 0) or shrink every frame: a tunnel
//@slider min=-5.0 max=5.0 value=0.0
uniform float trail_rotate;         // the trails turn every frame, degrees
//@slider min=0.0 max=0.05 value=0.0
uniform float trail_hue;            // the trails change their colour every frame
//@slider min=0.0 max=1.0 value=0.3
uniform float beat_punch;           // a taller, brighter wave at every beat
//@rgb value=(0.0, 0.0, 0.0)
uniform vec3 background;

vec3 hue(float h) {
    return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// Turns a colour around the grey axis (a hue shift without a round trip through HSV)
vec3 hueShift(vec3 c, float turns) {
    float a = turns * AUDIO_TAU;
    vec3 k = vec3(0.57735);
    return c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cos(a));
}

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// The last frame at a pixel position, bilinear (the textures of passes are nearest)
vec3 lastFrame(vec2 p) {
    ivec2 size_px = textureSize(feedback, 0);
    vec2 q = p - 0.5;
    ivec2 i0 = ivec2(floor(q));
    vec2 f = q - floor(q);
    ivec2 hi = size_px - 1;
    vec3 a = texelFetch(feedback, clamp(i0, ivec2(0), hi), 0).rgb;
    vec3 b = texelFetch(feedback, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0).rgb;
    vec3 c = texelFetch(feedback, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0).rgb;
    vec3 d = texelFetch(feedback, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0).rgb;
    float inside = step(0.0, p.x) * step(0.0, p.y) * step(p.x, float(size_px.x)) * step(p.y, float(size_px.y));
    return stateOr(vec4(mix(mix(a, b, f.x), mix(c, d, f.x), f.y) * inside, 0.0), vec4(0.0)).rgb;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    float k = res.y / 1080.0;
    vec4 st = texelFetch(T, ivec2(0), 0);
    float start = st.r;
    float g = gain * (auto_gain ? 0.7 / max(st.g, 0.05) : 1.0) * (1.0 + beat_punch * 0.6 * st.b);
    int win = clamp(window, 32, 480);
    float fwin = float(win);
    vec2 c = 0.5 * res + position * res.y;
    vec2 p = fragCoord;
    float th = max(thickness * k * (1.0 + beat_punch * 0.8 * st.b), 0.75);

    float dist = 1e9;
    float along = 0.0;          // 0 .. 1 along the line, for Rainbow
    float body = 0.0;           // Filled: inside the filled part

    if (mode == 3) {
        vec2 q = p - c;
        float r = length(q);
        float a = fract(atan(q.x, q.y) / AUDIO_TAU + 1.0);  // 0 at the top, clockwise
        float R = radius * res.y;
        float amp = size * 0.25 * res.y;
        // the ends of the wave fade into the ring, so it closes without a step
        float s = start + a * fwin;
        float taper = smoothstep(0.0, 0.06, a) * smoothstep(1.0, 0.94, a);
        float w = clamp(waveAt(s) * g, -1.5, 1.5) * taper;
        float w2 = clamp(waveAt(s + 1.0) * g, -1.5, 1.5) * taper;
        float rw = R + w * amp;
        float drds = (w2 - w) * amp;                               // per sample
        float dsd = drds * fwin / AUDIO_TAU / max(rw, 1.0);        // slope along the ring, at the wave
        dist = abs(r - rw) / sqrt(1.0 + dsd * dsd);
        along = a;
    } else {
        float amp = size * 0.5 * res.y;
        float pps = res.x / fwin;                                  // pixels per sample
        float s = start + p.x / pps;
        int K = clamp(int(ceil((th + 2.0) / pps)) + 1, 1, 8);
        int j0 = int(floor(s));
        vec2 prev = vec2(0.0);
        for (int j = j0 - K; j <= j0 + K + 1; j++) {
            float x = (float(j) - start) * pps;
            float w = clamp(audioSample(j) * g, -1.5, 1.5);
            vec2 pt = vec2(x, c.y + w * amp);
            if (j > j0 - K) {
                dist = min(dist, segDist(p, prev, pt));
                if (mode == 1)
                    dist = min(dist, segDist(p, vec2(prev.x, 2.0 * c.y - prev.y), vec2(pt.x, 2.0 * c.y - pt.y)));
            }
            prev = pt;
        }
        if (mode == 2) {
            float yw = c.y + clamp(waveAt(s) * g, -1.5, 1.5) * amp;
            float lo = min(c.y, yw), hi = max(c.y, yw);
            body = smoothstep(lo - 1.0, lo, p.y) * (1.0 - smoothstep(hi, hi + 1.0, p.y));
        }
        along = p.x / res.x;
    }

    vec3 lc = mix(line_color, hue(along + iTime * 0.125), rainbow);
    float bright = 1.0 + beat_punch * st.b;
    float core = 1.0 - smoothstep(th * 0.5 - 0.75, th * 0.5 + 0.75, dist);
    float halo = glow * exp(-dist / max(glow_size * k, 0.5)) * 0.6;
    vec3 cur = lc * (core + halo + body * 0.35) * bright + vec3(core * 0.35 * bright);

    // The trails: the last frame without the background, moved around the middle, faded, its colour turned
    vec3 old = vec3(0.0);
    if (trail > 0.0 && iFrame > 1) {
        float ang = radians(trail_rotate);
        mat2 rot = mat2(cos(ang), sin(ang), -sin(ang), cos(ang));
        vec2 from = c + rot * (p - c) / (1.0 + trail_zoom);
        old = max(lastFrame(from) - background, 0.0) * trail;
        if (trail_hue > 0.0)
            old = max(hueShift(old, trail_hue), 0.0);
    }

    // max, not a sum: a long trail does not burn into white
    vec3 col = min(max(old, cur), vec3(2.0));
    fragColor = vec4(background + col, 1.0);
}
