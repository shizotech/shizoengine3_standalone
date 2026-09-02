// Strudel
// A rotating logarithmic spiral that spirals into the centre of the
// screen, and can morph into a trippy / psychedelic warped pattern.
// Shadertoy-style mainImage. iResolution / iTime / iFrame / iMouse are
// engine-injected - do NOT redeclare them.

//@settings dtype=float32 format=rgba

// ---- Configurable uniforms ----
//@float min=0.05 max=1.0 value=0.4
uniform float spiral_size;

//@float min=0.5 max=3.0 value=1.0
uniform float zoom;

//@float min=0.0 max=1.0 value=0.5
uniform float smoothness;

//@float min=0.0 max=5.0 value=1.0
uniform float rotation_speed;

//@float min=0.0 max=1.0 value=0.5
uniform float mod_amount;

//@rgb value=(1.0,0.9,0.5)
uniform vec3 fg_colour;

//@rgb value=(0.05,0.05,0.15)
uniform vec3 bg_colour;

// =====================================================================
// Helpers
// =====================================================================
float hash_f(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// 2D value noise
float noise(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth 2D value noise (smootherstep interpolated).
float noise_smooth(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x),
                mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 2D rotation by angle a.
vec2 rot2(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Hue-cycled "trippy" colour from a phase value.
vec3 trippy_col(float phase) {
    return 0.5 + 0.5 * cos(vec3(0.0, 2.09, 4.19) + 6.2832 + phase);
}

// =====================================================================
// Main
// =====================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalised, aspect-corrected, centered coordinates.
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / iResolution.y;

    // ---- Apply zoom ----
    p /= max(zoom, 0.1);

    // ---- Rotation over time (rotation_speed) ----
    p = rot2(p, iTime * rotation_speed);

    // ---- Spiral size: larger value -> bigger spiral filling the screen ----
    p /= max(spiral_size, 0.01);

    // ---- Trippy warp driven by mod_amount ----
    // Noise-based coordinate distortion: at 0 it's a clean spiral,
    // at 1 it's fully warped/morphed into a psychedelic shape.
    float wt = iTime * 0.5;
    vec2 warp = vec2(noise_smooth(p * 3.0 + wt) - 0.5,
                      noise_smooth(p * 3.0 - wt) - 0.5);
    warp *= mod_amount * 0.4;
    vec2 pw = p + warp;

    // ---- Logarithmic spiral field ----
    // r = r0 * exp(B * theta)  ->  log(r) - B*theta = const per arm.
    const float B = 0.30;
    float theta = atan(pw.y, pw.x);
    float r = length(pw);
    float phase = B * theta - log(r + 1e-4);

    // Spiral line mask: peaks of cos(phase) are the spiral arms.
    float lines = cos(phase);
    // Smoothness widens the spiral line edges.
    float width = mix(0.02, 0.5, smoothness);
    float line_mask = 1.0 - smoothstep(1.0 - width, 1.0, lines);

    // ---- Colours ----
    // Base colour: flat background.
    vec3 col = bg_colour;

    // Spiral line colour: clean fg_colour that morphs into a
    // hue-cycled trippy colour as mod_amount increases.
    vec3 line_col = mix(fg_colour, trippy_col(phase * (1.0 + mod_amount * 5.0) + iTime), mod_amount);
    col = mix(col, line_col, line_mask);

    // Trippy background pattern, only visible as mod_amount grows.
    float psy = sin(phase * (2.0 + mod_amount * 8.0) + iTime);
    vec3 psy_col = trippy_col(psy * (1.0 + mod_amount * 3.0) + iTime * 0.3);
    col = mix(col, psy_col, mod_amount * 0.35);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
