// WaveFloat-Noise
// A wavering plasma-style wavy background (GroundLayer) with free-flying
// "rumfliegen" particles of random sizes scattered across the full screen
// (ItemLayer). Shadertoy-style mainImage. iResolution/iTime/iFrame/iMouse
// are engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Background (GroundLayer) ----
//@float min=0.01 max=3.0 value=0.5
uniform float noise_speed_ground;

//@float min=0.0 max=3.0 value=0.6
uniform float noise_depth_ground;

// ---- Items (ItemLayer) ----
//@float min=0.0 max=1.0 value=0.2
uniform float noise_depth_item;

// ---- Object size (kleinste / größte Objektgröße) ----
//@float min=0.02 max=0.30 value=0.05
uniform float min_object_size;

//@float min=0.05 max=0.60 value=0.30
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

// ---- Colours ----
//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.05,0.05,0.15)
uniform vec3 bg_colour;

// ---- Shape selector (mode 0..5) ----
//@enum options=(Hex, Rund, Random, Heart, Cross, Cloud)
uniform int shape_mode;

// ---- Particle count ----
//@float min=1 max=200 value=60
uniform float particle_count;

// =====================================================================
// Helpers
// =====================================================================
// Per-ID pseudo-random hash (ParticleStorm style)
float hash1(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// 2D value noise (Smoke style)
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

// Shape selection by shape_mode (0..5). Random/Cloud use a per-ID seed
// for noise-deformed blobs.
float shape_sdf(vec2 p, float r, float seed) {
    if (shape_mode == 0) {
        return sd_hex(p, r);
    } else if (shape_mode == 1) {
        return sd_circle(p, r);
    } else if (shape_mode == 2) {
        // Random: noise-deformed blob
        float n  = noise_smooth(p * 3.0 + vec2(seed * 1.3, iTime * 0.5));
        float n2 = noise_smooth(p * 6.0 + vec2(seed * 2.1, iTime * 0.3));
        return sd_circle(p, r) + (n * 0.6 + n2 * 0.4 - 0.5) * 2.0 * (r * 0.35);
    } else if (shape_mode == 3) {
        return sd_heart(p, r * 0.7);
    } else if (shape_mode == 4) {
        return sd_cross(p, r);
    } else {
        // Cloud: puffier noise-deformed blob
        float n  = noise_smooth(p * 2.0 + vec2(seed * 2.0, iTime * 0.4));
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

    // ---- Wavering plasma background (GroundLayer) ----
    // Classic plasma via overlapping sines, scaled by noise_speed_ground,
    // with depth modulated by noise_depth_ground.
    float gt = iTime * noise_speed_ground;
    float v = 0.0;
    v += sin(uv.x * 3.0 + gt);
    v += sin(uv.y * 3.0 + gt * 1.3);
    v += sin((uv.x + uv.y) * 2.0 + gt * 0.7);
    v += sin(length(uv - vec2(0.5)) * 4.0 - gt * 1.5);
    v += sin(length(uv - vec2(0.3, 0.7)) * 3.0 + gt * 0.8);

    v = v * 0.1666666 * noise_depth_ground;
    v = fract(v);

    // Map plasma value to a blend from bg_colour toward a mid tone.
    vec3 col = mix(bg_colour, bg_colour + vec3(0.15, 0.10, 0.05), v);

    // ---- Free-flying particles (ItemLayer) ----
    // Particles "rumfliegen": random initial positions, random drift
    // velocities, per-ID random sizes, wrap-around across the full screen.
    const int MAX = 200;
    int count = int(particle_count);

    for (int i = 0; i < MAX; i++) {
        if (i >= count) {
            break;
        }
        float id = float(i);

        // Per-ID hash values.
        float h1 = hash1(id);
        float h2 = hash1(id + 37.0);
        float h3 = hash1(id + 91.0);
        float h4 = hash1(id + 151.0);

        // Random base position inside normalized uv space.
        vec2 base = vec2(h1, h2);

        // Random drift direction (angle) and speed.
        float angle = (h3 - 0.5) * 6.28318;
        vec2 dir = vec2(cos(angle), sin(angle));
        float speed = 0.02 + h4 * 0.06;

        // Position = base + drift * iTime, wrapped into [0,1].
        vec2 pos = fract(base + dir * speed * iTime);

        // Per-ID random size in [min_object_size, max_object_size].
        float size = min_object_size + (max_object_size - min_object_size) * hash1(id + 211.0);

        // Local, centered coordinate for SDF evaluation.
        vec2 p = uv - pos;

        // Optional rotation of the SDF space.
        if (rotate_items) {
            p = rot2(p, iTime * 0.4 + id);
        }

        // Per-ID seed for Random/Cloud shape variation.
        float seed = hash1(id + 333.0);

        // Base SDF for the selected shape mode.
        float d = shape_sdf(p, size, seed);

        // ItemLayer noise deformation.
        d += (noise_smooth(p * 4.0 + vec2(iTime * 0.3, seed)) - 0.5) * 2.0 * noise_depth_item * size;

        // Filled body; Smoothen Items controls edge smoothing width.
        float fill = 1.0 - smoothstep(-smoothen_items, smoothen_items, d);
        col = mix(col, fg_colour, fill);

        // Nested outline rings (Item-Frame Depth).
        const int FRAME_COUNT = 4;
        for (int k = 1; k <= FRAME_COUNT; k++) {
            float off = float(k) * 0.10 * item_frame_depth * size;
            float ring = 1.0 - smoothstep(0.0, 0.02 * size, abs(d - off));
            col = mix(col, fg_colour * 0.5, ring);
        }
    }

    // ---- Contrast adjustment ----
    col = (col - 0.5) * contrast + 0.5;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
