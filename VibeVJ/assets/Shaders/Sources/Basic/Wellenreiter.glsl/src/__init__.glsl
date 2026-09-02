// Wellenreiter
// Concentric waves emanating from the screen center, expanding toward the
// edges with an optional bounce at the edges. Shadertoy-style mainImage.
// iResolution/iTime/iFrame/iMouse are engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Wave parameters ----
//@float min=0.0 max=1.0 value=0.10
uniform float smoothness;

//@float min=0.05 max=1.0 value=0.25
uniform float wave_spacing;

//@float min=0.0 max=2.0 value=0.6
uniform float wave_depth;

//@float min=0.0 max=0.5 value=0.10
uniform float morph_strength;

//@float min=0.0 max=0.5 value=0.0
uniform float center_offset;

// ---- Colours ----
//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.05,0.05,0.15)
uniform vec3 bg_colour;

// ---- Wave shape selector (mode 0..4) ----
//@enum options=(Sinus, Triangle, Square, Sawtooth, Noise)
uniform int wave_shape_mode;

// =====================================================================
// Helpers
// =====================================================================
// Per-ID / per-pixel pseudo-random hash
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

// Wave shapes (t = normalized phase). Returns value in [-1, 1].
// Triangle effectively implements the "bounce" behaviour (waves travel
// outward and back - 1.0 - abs(fract(t)-0.5)*2.0)
float wave_shape(float t, float seed) {
    if (wave_shape_mode == 0) {
        // Sinus
        return sin(t * 6.28318530718);
    } else if (wave_shape_mode == 1) {
        // Triangle (edge bounce)
        return 1.0 - abs(fract(t) - 0.5) * 4.0;
    } else if (wave_shape_mode == 2) {
        // Square
        return step(0.5, fract(t)) * 2.0 - 1.0;
    } else if (wave_shape_mode == 3) {
        // Sawtooth
        return fract(t) * 2.0 - 1.0;
    } else {
        // Noise-based wave
        float n = noise_smooth(vec2(t * 2.0 + seed * 3.0, iTime * 0.5 + seed));
        return n * 2.0 - 1.0;
    }
}

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized screen-space uv in [0,1]
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 center = vec2(0.5);

    // Per-pixel seed for Noise shape variation
    float seed = hash1(dot(fragCoord.xy, vec2(0.1, 0.7)) * 0.001);

    // Radial noise morphing of the radius (morph_strength)
    float morph = (noise_smooth(uv * 3.0 + vec2(iTime * 0.2, seed)) - 0.5) * 2.0 * morph_strength;

    // Distance from center, subtract center_offset, add morphing noise
    float r = length(uv - center) - center_offset + morph;

    // Normalize to wave phase and animate
    float t = r / wave_spacing;
    t += iTime * 0.5;

    // Evaluate the selected wave shape, scale by wave_depth
    float w = wave_shape(t, seed) * wave_depth;

    // Map to 0..1 for bg->fg blend
    float v = clamp(w * 0.5 + 0.5, 0.0, 1.0);

    // Smoothness controls the smoothstep band width for the blend
    float smooth_w = max(smoothness, 0.001);
    float blend = smoothstep(0.5 - smooth_w, 0.5 + smooth_w, v);

    vec3 col = mix(bg_colour, fg_colour, blend);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
