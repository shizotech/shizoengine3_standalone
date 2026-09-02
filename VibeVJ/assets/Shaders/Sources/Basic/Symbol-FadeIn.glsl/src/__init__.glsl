// Symbol-FadeIn
// A flat, solid-color background with a single central symbol that
// fades in: it grows from min_object_size up to max_object_size,
// then holds at the largest size. Shadertoy-style mainImage;
// iResolution/iTime/iFrame/iMouse are engine-injected - do NOT
// redeclare them.

//@settings dtype=float32 format=rgba

// ---- Object size (kleinste / größte Objektgröße) ----
//@float min=0.02 max=0.30 value=0.06
uniform float min_object_size;

//@float min=0.05 max=0.60 value=0.35
uniform float max_object_size;

// ---- Behaviour ----
//@button
uniform bool rotate_items;

//@float min=0.0 max=0.1 value=0.005
uniform float smoothen_items;

//@float min=0.0 max=1.0 value=0.4
uniform float item_frame_depth;

//@float min=0.1 max=3.0 value=1.0
    uniform float contrast;

    //@float min=1.0 max=10.0 value=4.0
    uniform float cycle_duration;

// ---- Grid overlay ----
//@button
uniform bool show_grid;

//@float min=0 max=1 value=1
uniform float grid_density;

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
// hashing for per-frame variation.
float shape_sdf(vec2 p, float r, float seed) {
    float t = iTime * 0.5;
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

    // ---- Flat / solid-color background (einfarbig) ----
    vec3 col = bg_colour;

    // ---- Optional subtle grid overlay ----
    if (show_grid) {
        float density = 8.0 + grid_density * 24.0;
        vec2 g = abs(fract(uv * density) - 0.5);
        float line = min(g.x, g.y);
        float grid_alpha = 1.0 - smoothstep(0.0, 0.08, line);
        col = mix(col, fg_colour * 0.12, grid_alpha);
    }

    // ---- Single central symbol with looping FadeIn behaviour ----
    // Loops: grows (alpha 0->1, size min->max), holds briefly at full
    // size, then shrinks/fades back to nothing, then the cycle repeats.
    // Phase in [0,1] driven by fract(iTime / cycle_duration).
    float phase = fract(iTime / cycle_duration);
    const float GROW_END   = 0.5;   // phase fraction where growth finishes
    const float HOLD_END   = 0.6;   // phase fraction where hold finishes
    float size;
    float alpha;
    if (phase <= GROW_END) {
        // Grow phase: fade in + grow to max size
        float p = phase / GROW_END;          // 0..1
        size  = mix(min_object_size, max_object_size, p);
        alpha = p;
    } else if (phase <= HOLD_END) {
        // Brief hold at full size / full alpha
        size  = max_object_size;
        alpha = 1.0;
    } else {
        // Fade-out / shrink back to nothing, then the loop restarts
        float q = (phase - HOLD_END) / (1.0 - HOLD_END);  // 0..1
        size  = mix(max_object_size, min_object_size, q);
        alpha = 1.0 - q;
    }

    // Local coordinates centred on the screen middle.
    vec2 pp = uvc;

    // Optional slow rotation.
    if (rotate_items) {
        pp = rot2(pp, iTime * 0.3);
    }

    // iFrame-based seed for Random/Cloud variation.
    float seed = hash_f(float(iFrame) * 0.01);

    // Base SDF for the selected shape.
    float d = shape_sdf(pp, size, seed);

    // Filled body, smoothen_items controls the edge smoothing window.
    float fill = 1.0 - smoothstep(-smoothen_items, smoothen_items, d);
    col = mix(col, fg_colour * alpha, fill * alpha);

    // Nested frames / rings around the symbol (item_frame_depth).
    const int FRAME_COUNT = 4;
    for (int k = 1; k <= FRAME_COUNT; k++) {
        float off = float(k) * 0.12 * item_frame_depth;
        float ring = 1.0 - smoothstep(0.0, 0.02, abs(d - off));
        col = mix(col, fg_colour * alpha * 0.5, ring);
    }

    // ---- Contrast adjustment ----
    col = (col - 0.5) * contrast + 0.5;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
