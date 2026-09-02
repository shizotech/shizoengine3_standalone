// Matrix_Formen
// A grid (matrix) of SDF shapes that grow and shrink in a looping cycle.
// Per-cell offset drives a wavelike size progression across the raster.
// Shadertoy-style mainImage. iResolution/iTime/iFrame/iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Grid dimensions ----
//@float min=1 max=16 value=6
uniform float cols;

//@float min=1 max=16 value=6
uniform float rows;

// ---- Object size (kleinstes / größtes Symbol) ----
//@float min=0.02 max=0.30 value=0.06
uniform float min_object_size;

//@float min=0.05 max=0.60 value=0.35
uniform float max_object_size;

// ---- Temporal cycle timings ----
//@float min=0.1 max=5.0 value=0.8
uniform float fadein_time;

//@float min=0.0 max=5.0 value=0.6
uniform float hold_time;

//@float min=0.1 max=5.0 value=0.8
uniform float fadeout_time;

// ---- Shape selector (mode 0..5) ----
//@enum options=(Hex, Rund, Random, Heart, Cross, Cloud)
uniform int shape_mode;

// ---- Edge smoothing ----
//@float min=0.0 max=0.2 value=0.015
uniform float smoothness;

// ---- Colours ----
//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.05,0.05,0.15)
uniform vec3 bg_colour;

// ---- Rotation behaviour ----
//@button
uniform bool rotate_items;

//@float min=0.0 max=5.0 value=0.5
uniform float rotation_speed;

// =====================================================================
// Helpers
// =====================================================================
// Per-cell pseudo-random hash
float hash1(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// 2D value noise
float noise(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth 2D value noise
float noise_smooth(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x),
                mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 2D rotation
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

// Shape selection by shape_mode (0..5). Random/Cloud use per-cell seeds
// for noise-deformed blobs.
float shape_sdf(vec2 p, float r, float seed) {
    float t = iTime * 0.5;
    if (shape_mode == 0) {
        return sd_hex(p, r);
    } else if (shape_mode == 1) {
        return sd_circle(p, r);
    } else if (shape_mode == 2) {
        // Random: noise-deformed blob
        float n  = noise_smooth(p * 3.0 + vec2(seed * 1.3, t));
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
    // Normalized screen-space uv in [0,1].
    vec2 uv = fragCoord.xy / iResolution.xy;

    // ---- Background ----
    vec3 col = bg_colour;

    // ---- Grid cell for the current pixel ----
    float cols_f = max(cols, 1.0);
    float rows_f = max(rows, 1.0);
    vec2 cell = floor(uv * vec2(cols_f, rows_f));

    // Per-cell seed for shape variation and cycle phase offset
    float cell_seed = hash1(cell.x * 13.0 + cell.y * 7.0 + 42.0);

    // Per-cell phase offset produces a wavelike progression across the
    // raster: neighbouring cells are phase-shifted by a small constant.
    float cell_phase_offset = (cell.x + cell.y) * 0.08;

    // ---- Temporal grow/hold/shrink cycle ----
    // Total cycle = fadein_time + hold_time + fadeout_time
    float cycle_total = max(fadein_time, 0.1) + max(hold_time, 0.0) + max(fadeout_time, 0.1);
    // Per-cell phase in [0,1]
    float phase = fract((iTime + cell_phase_offset) / cycle_total);

    float fadein_norm  = max(fadein_time, 0.1) / cycle_total;
    float hold_norm    = max(hold_time, 0.0) / cycle_total;
    float fadeout_norm = max(fadeout_time, 0.1) / cycle_total;

    // Compute size and alpha based on which phase segment we're in
    float size;
    float alpha;
    if (phase <= fadein_norm) {
        // Grow phase: size grows from min to max, alpha fades in
        float p = phase / fadein_norm;  // 0..1
        size  = mix(min_object_size, max_object_size, p);
        alpha = p;
    } else if (phase <= fadein_norm + hold_norm) {
        // Hold phase: full size, full alpha
        size  = max_object_size;
        alpha = 1.0;
    } else {
        // Shrink/fadeout phase: size shrinks from max to min, alpha fades out
        float q = (phase - fadein_norm - hold_norm) / fadeout_norm;  // 0..1
        size  = mix(max_object_size, min_object_size, q);
        alpha = 1.0 - q;
    }

    // ---- Local cell-centred coordinate for SDF evaluation ----
    // Center of the current cell in normalized uv space
    vec2 cell_center = (cell + vec2(0.5, 0.5)) / vec2(cols_f, rows_f);
    vec2 p = uv - cell_center;

    // Optional per-cell rotation (rotation_speed) when rotate_items is on
    if (rotate_items) {
        p = rot2(p, iTime * rotation_speed + cell_seed * 6.28318);
    }

    // Per-cell seed for Random/Cloud variation
    float seed = hash1(cell.x * 31.0 + cell.y * 17.0 + 999.0);

    // Base SDF for the selected shape mode
    float d = shape_sdf(p, size, seed);

    // Filled body; smoothness controls the edge smoothing window
    float sm = max(smoothness, 0.002);
    float fill = 1.0 - smoothstep(-sm, sm, d);
    col = mix(col, fg_colour * alpha, fill * alpha);

    // Subtle per-cell outline ring (optional frame)
    float ring = 1.0 - smoothstep(0.0, max(sm, 0.001), abs(d - size * 0.15));
    col = mix(col, fg_colour * alpha * 0.5, ring * 0.4);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
