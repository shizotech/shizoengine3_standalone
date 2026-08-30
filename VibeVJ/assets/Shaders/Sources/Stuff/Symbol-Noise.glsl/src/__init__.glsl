// Symbol-Noise
// A wavering wavy background layer with cycling symbol "items" that
// grow from min to max size, hold, then shrink and fade out.
// Shadertoy-style mainImage. iResolution/iTime/iFrame/iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Background (GroundLayer) ----
//@float min=0.0 max=2.0 value=0.6
uniform float noise_depth_ground;

//@float min=0.0 max=3.0 value=0.5
uniform float noise_speed_ground;

// ---- Items (ItemLayer) ----
//@float min=0.0 max=1.0 value=0.2
uniform float noise_depth_item;

//@float min=0.0 max=3.0 value=0.5
uniform float noise_speed_item;

// ---- Object size (kleinste / größte Objektgröße) ----
//@float min=0.02 max=0.30 value=0.06
uniform float min_object_size;

//@float min=0.05 max=0.60 value=0.35
uniform float max_object_size;

// ---- Timing ----
//@float min=0.1 max=5.0 value=0.8
uniform float fadein_time;

//@float min=0.1 max=5.0 value=0.8
uniform float fadeout_time;

//@float min=0.0 max=10.0 value=1.2
uniform float hold_time;

// ---- Behaviour ----
//@button
uniform bool rotate_items;

//@float min=0.0 max=0.1 value=0.005
uniform float smoothen_items;

//@float min=0.0 max=1.0 value=0.4
uniform float item_frame_depth;

//@float min=0.1 max=3.0 value=1.0
uniform float contrast;

// ---- Colours ----
//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.05,0.05,0.15)
uniform vec3 bg_colour;

// ---- Shape selector (mode 0..5) ----
//@enum options=(Hex, Rund, Random, Heart, Cross, Cloud)
uniform int shape_mode;

// =====================================================================
// Helpers
// =====================================================================
float hash_f(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// 2D value noise (from Smoke.glsl style)
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

vec2 rot2(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Small per-item positional offset so items don't perfectly overlap.
vec2 item_offset(int i) {
    return vec2((hash_f(float(i) * 3.7) - 0.5) * 0.15,
                 (hash_f(float(i) * 7.1) - 0.5) * 0.15);
}

// ---- SDF shapes ----
float sd_hex(vec2 p, float r) {
    p = abs(p);
    return min(max(p.x * 0.866025 + p.y * 0.5, p.y), r) - 0.5 * r;
}

float sd_circle(vec2 p, float r) {
    return length(p) - r;
}

float sd_heart(vec2 p, float s) {
    p.x = abs(p.x);
    float a = p.y + s;
    float x2 = p.x * p.x - a * a;
    return x2 * x2 * x2 + p.y * p.y * p.y - s * s * s;
}

float sd_cross(vec2 p, float s) {
    vec2 q = abs(p);
    float a = max(q.y - s * 0.35, q.x - s);
    float b = max(q.x - s * 0.35, q.y - s);
    return min(a, b);
}

// Shape selection by shape_mode (0..5). Random/Cloud use iFrame-based
// hashing for per-object variation.
float shape_sdf(vec2 p, float r, float seed, int item) {
    float t = iTime * noise_speed_item;
    if (shape_mode == 0) {
        return sd_hex(p, r);
    } else if (shape_mode == 1) {
        return sd_circle(p, r);
    } else if (shape_mode == 2) {
        // Random: noise-deformed blob
        float n = noise_smooth(p * 3.0 + vec2(seed * 1.3, t));
        float n2 = noise_smooth(p * 6.0 + vec2(seed * 2.1, t * 0.7));
        return sd_circle(p, r) + (n * 0.6 + n2 * 0.4 - 0.5) * 2.0 * (r * 0.35);
    } else if (shape_mode == 3) {
        return sd_heart(p, r * 0.7);
    } else if (shape_mode == 4) {
        return sd_cross(p, r);
    } else {
        // Cloud: puffier noise-deformed blob
        float n  = noise_smooth(p * 2.0 + vec2(seed * 2.0, t));
        float n2 = noise_smooth(p * 5.0 + vec2(0.0, seed));
        return sd_circle(p, r) + (n * 0.6 + n2 * 0.4 - 0.5) * 2.0 * (r * 0.5);
    }
}

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 uvc = uv - 0.5;
    uvc.x *= iResolution.x / iResolution.y;

    // ---- Wavy background (GroundLayer) ----
    float gt = iTime * noise_speed_ground;
    float n1 = noise_smooth(uv * 4.0 + vec2(gt * 0.3, gt * 0.5));
    float n2 = noise_smooth(uv * 8.0 + vec2(n1, gt * 0.4)) * 0.5;
    float n3 = noise_smooth(uv * 16.0 + vec2(n2, gt * 0.6)) * 0.25;
    float bg = (n1 + n2 + n3) * noise_depth_ground;
    vec3 col = mix(vec3(0.0), bg_colour, bg);

    // ---- Cycling symbol items ----
    const int ITEM_COUNT = 4;
    float total_cycle = fadein_time + hold_time + fadeout_time;

    for (int i = 0; i < ITEM_COUNT; i++) {
        // Per-item phase offset so items cycle continuously.
        float offset = float(i) * (total_cycle / float(ITEM_COUNT));
        float prog = mod(iTime + offset, total_cycle);

        float alpha;
        float size;
        if (prog < fadein_time) {
            float tt = prog / max(fadein_time, 0.001);
            size = min_object_size + (max_object_size - min_object_size) * tt;
            alpha = tt;
        } else if (prog < fadein_time + hold_time) {
            size = max_object_size;
            alpha = 1.0;
        } else {
            float tt = (prog - fadein_time - hold_time) / max(fadeout_time, 0.001);
            size = max_object_size - (max_object_size - min_object_size) * tt;
            alpha = 1.0 - tt;
        }

        // Position near centre with a small per-item offset.
        vec2 p = uvc - item_offset(i);

        // Optional slow rotation.
        if (rotate_items) {
            p = rot2(p, iTime * 0.3 + float(i));
        }

        // iFrame-based seed for Random/Cloud variation.
        float seed = hash_f(float(iFrame) * 0.01 + float(i) * 17.0);

        // Base SDF for the selected shape.
        float d = shape_sdf(p, size, seed, i);

        // ItemLayer noise deformation.
        float it = iTime * noise_speed_item;
        d += (noise_smooth(p * 4.0 + vec2(it, seed)) - 0.5) * 2.0 * noise_depth_item * size;

        // Filled body, with Smoothen Items controlling edge smoothing.
        float fill = 1.0 - smoothstep(-smoothen_items, smoothen_items, d);
        col = mix(col, fg_colour * alpha, fill * alpha);

        // Nested frames / outlines around each object (Item-Frame Depth).
        const int FRAME_COUNT = 4;
        for (int k = 1; k <= FRAME_COUNT; k++) {
            float off = float(k) * 0.12 * item_frame_depth;
            float ring = 1.0 - smoothstep(0.0, 0.02, abs(d - off));
            col = mix(col, fg_colour * alpha * 0.5, ring);
        }
    }

    // ---- Contrast adjustment ----
    col = (col - 0.5) * contrast + 0.5;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
