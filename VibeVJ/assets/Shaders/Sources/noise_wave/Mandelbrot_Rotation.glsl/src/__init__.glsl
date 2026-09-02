// Mandelbrot_Rotation
// The Mandelbrot set drawn as three stacked layers rotating against each
// other (different rotation rates/directions per layer: +0.2, -0.15, +0.1
// rad/s). Shadertoy-style mainImage. iResolution/iTime/iFrame/iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Colours ----
//@rgb value=(0.35,0.65,1.0)
uniform vec3 fg_colour;

//@rgb value=(0.03,0.03,0.10)
uniform vec3 bg_colour;

// ---- Morph ----
//@float min=0.0 max=2.0 value=0.4
uniform float morph_strength;

// ---- Colour bands (number of coloured bands/steps) ----
//@float min=1 max=32 value=8
uniform float colour_depth;

// ---- Scaling of the set ----
//@float min=0.1 max=5.0 value=1.0
uniform float scaling;

// ---- Frame width around the coloured region ----
//@float min=0.0 max=0.3 value=0.03
uniform float item_frame_width;

// ---- Edge smoothing ----
//@float min=0.0 max=0.2 value=0.02
uniform float smoothness;

// =====================================================================
// Helpers
// =====================================================================
vec2 rot2(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// 2D value noise for morphing the set.
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

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized screen-space uv in [0,1].
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Centered, aspect-corrected coordinate, scaled by 'scaling'.
    // Mandelbrot centre at (-0.75, 0).
    float aspect = iResolution.x / iResolution.y;
    vec2 p0 = (uv - 0.5) * vec2(aspect, 1.0) * (2.0 * scaling) + vec2(-0.75, 0.0);

    vec3 col = bg_colour;

    // ---- Three stacked, counter-rotating Mandelbrot layers ----
    const int LAYER_COUNT = 3;
    const int MAX_ITER = 64;
    int bands = max(1, int(colour_depth));

    for (int k = 0; k < LAYER_COUNT; k++) {
        // Per-layer rotation rate (rad/s) and direction:
        // layer 0: +0.2, layer 1: -0.15, layer 2: +0.1
        float rate;
        if (k == 0) {
            rate = 0.2;
        } else if (k == 1) {
            rate = -0.15;
        } else {
            rate = 0.1;
        }

        // Rotate the complex plane around the set centre.
        vec2 p = rot2(p0, rate * iTime + float(k) * 0.7);

        // Optional morphing: radial noise perturbation of the start point.
        p += (noise_smooth(p * 2.0 + vec2(float(k) * 10.0, iTime * 0.15)) - 0.5) * 0.6 * morph_strength;

        // Finite Mandelbrot iteration.
        vec2 z = p;
        float iter = 0.0;
        for (int it = 0; it < MAX_ITER; it++) {
            if (dot(z, z) > 4.0) {
                iter = float(it);
                break;
            }
            z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + p;
        }

        // Normalized escape parameter: 0 inside the set, ~1 far outside.
        float t = iter / float(MAX_ITER);

        // ---- Banded colouring (colour_depth bands) ----
        float band_f = t * float(bands);
        float band = floor(band_f);
        float fracb = band_f - band;

        // Smooth-edged banding: full colour at the band centre, faded at
        // the band edges, controlled by 'smoothness'.
        float soft = 1.0 - smoothstep(0.0, max(smoothness, 0.001), abs(fracb - 0.5));

        // Band phase drives a sinusoidal brightness modulation of fg_colour.
        float phase = band / float(bands);
        float mod = 0.35 + 0.65 * (0.5 + 0.5 * cos(6.28318 * phase));
        col = mix(col, mix(bg_colour, fg_colour, mod), soft * (1.0 / 3.0));

        // ---- Frame around the coloured region (width = item_frame_width) ----
        float frame = 1.0 - smoothstep(0.0, max(item_frame_width, 0.001), t);
        col = mix(col, fg_colour, frame * 0.6);
    }

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
