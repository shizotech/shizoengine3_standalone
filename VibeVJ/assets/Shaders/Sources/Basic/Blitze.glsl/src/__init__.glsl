// Blitze
// Lightning bolts (Blitze) striking from the top of the screen to the
// bottom, flickering on/off in cyclic patterns. Each bolt follows a
// hashed random jagged path. Multiple layers with soft glow decay are
// composited on top of a flat background.
// Shadertoy-style mainImage. iResolution/iTime/iFrame/iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

//@float min=1 max=50 value=8
uniform float bolt_count;

//@float min=1 max=5 value=2
uniform float layer_count;

//@float min=0.0 max=1.0 value=0.5
uniform float smoothness;

//@float min=0.0 max=1.0 value=0.3
uniform float layer_blur;

//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.02,0.02,0.08)
uniform vec3 bg_colour;

//@float min=0.0 max=2.0 value=0.5
uniform float glow;

//@float min=0.0 max=2.0 value=1.0
uniform float sharpness;

// =====================================================================
// Helpers
// =====================================================================

// Per-ID pseudo-random hash (ParticleStorm / WaveFloat-Noise style).
float hash_f(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// 2D value noise (used for subtle path wobble).
float noise(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise_smooth(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x),
                mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Distance from point p to line segment a->b.
float sd_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t);
}

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 uvc = uv - 0.5;
    uvc.x *= iResolution.x / iResolution.y;

    // ---- Flat background ----
    vec3 col = bg_colour;

    // ---- Lightning bolts ----
    // For each of bolt_count bolts: hashed random start x, hashed random
    // flicker phase/speed, jagged path from top (y=1) to bottom (y=0).
    // The bolt is visible for part of its cycle (flackert auf/aus).
    // Per-bolt path is a polyline with 8 segments; midpoints are hashed
    // x-offsets plus a small time-varying noise wobble so the bolt
    // "crackles".
    const int BOLT_SEGS = 8;
    const int BOLT_PTS  = BOLT_SEGS + 1;

    int count = int(bolt_count);
    for (int i = 0; i < 50; i++) {
        if (i >= count) {
            break;
        }
        float id = float(i);

        // Per-bolt hashed attributes.
        float hx    = hash_f(id * 1.7);          // start x (0..1)
        float hphase = hash_f(id * 3.1);          // flicker phase
        float hspeed = 0.4 + hash_f(id * 5.3) * 1.2; // flicker speed
        float hwob   = hash_f(id * 7.9);          // wobble seed

        // Cyclic on/off: bolt visible only during the first 30% of its
        // flicker cycle (blitz "zuckt", dann kurz aus, dann wieder an).
        float cycle  = fract(iTime * hspeed + hphase);
        float on     = 1.0 - smoothstep(0.28, 0.32, cycle);

        // Build the jagged polyline from top (y=1) down to bottom (y=0).
        vec2 pts[BOLT_PTS];
        for (int s = 0; s <= BOLT_SEGS; s++) {
            float sy = 1.0 - (float(s) / float(BOLT_SEGS));
            float h  = hash_f(id * 13.0 + float(s) * 1.1);
            float x  = hx + (h - 0.5) * 0.18;
            // Subtle time-varying wobble along the path.
            x += (noise_smooth(vec2(sy * 4.0, iTime * 0.6 + hwob)) - 0.5) * 0.04;
            pts[s] = vec2(x, sy);
        }

        // Min segment distance from pixel to this bolt's polyline.
        float min_dist = 1e9;
        for (int s = 0; s < BOLT_SEGS; s++) {
            float d = sd_segment(uv, pts[s], pts[s + 1]);
            min_dist = min(min_dist, d);
        }

        // ---- Layered glow ----
        // layer_count layers, each wider than the previous (layer_blur
        // scales the extra width), intensity decays per layer, scaled
        // by glow. sharpness controls the edge hardness of each line;
        // higher sharpness -> thinner smoothstep window.
        int lcount = int(layer_count);
        for (int k = 0; k < 5; k++) {
            if (k >= lcount) {
                break;
            }
            float base_width = 0.004;
            float width_k = base_width + float(k) * layer_blur * 0.01;
            // Edge smoothing window shrinks as sharpness grows.
            float edge = 0.004 * max(0.0, 1.0 - sharpness * 0.5);
            float line = 1.0 - smoothstep(width_k - edge, width_k + edge, min_dist);
            // Smoothness further softens the transition.
            line = mix(line, 1.0 - smoothstep(width_k, width_k + 0.006 * (1.0 + smoothness), min_dist), smoothness * 0.5);

            float intensity = pow(0.55, float(k));
            col += fg_colour * intensity * glow * on * line;
        }
    }

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
