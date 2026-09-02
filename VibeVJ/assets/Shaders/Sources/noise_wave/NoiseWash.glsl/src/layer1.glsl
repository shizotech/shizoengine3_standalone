// FX1 NoiseWash - Pass 1 (NOISE WASH)
// Shadertoy format
// Full-screen noise wash with several selectable patterns.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Selectable noise pattern
//@enum options=(Value, Perlin, Scanlines, Static, Rings) value=0
uniform int noise_pattern;

// Noise amount / strength
//@slider min=0.0 max=1.0 value=0.6
uniform float noise_amount;

// Noise scale (fineness)
//@slider min=0.1 max=4.0 value=1.2
uniform float noise_scale;

// Animation speed
//@slider min=0.0 max=4.0 value=0.5
uniform float speed;

// Noise colour
//@rgb value=(0.25,0.5,0.9)
uniform vec3 noise_color;

// Background colour (kept non-black)
//@rgb value=(0.05,0.04,0.08)
uniform vec3 background;

// ---- hash / noise helpers ----
float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p.yx + vec2(34.23, 3.35));
    return fract((p.x + p.y) * p.x);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    float t = iTime * speed;
    float n;
    vec2 np = uv * iResolution.xy * 0.02 * noise_scale + vec2(t * 0.5, 0.0);

    if (noise_pattern == 0) {
        // Value noise: smooth 2D value noise
        n = value_noise(np);
    } else if (noise_pattern == 1) {
        // Perlin-like: two-octave value noise
        n = 0.5 * value_noise(np) + 0.5 * value_noise(np * 2.0 + 37.0);
    } else if (noise_pattern == 2) {
        // Scanlines: horizontal banding
        n = 0.5 + 0.5 * sin(fragCoord.y * 0.5 + t * 3.0);
    } else if (noise_pattern == 3) {
        // Static: per-pixel random per frame
        n = hash21(fragCoord * 0.5 + iFrame * 0.01);
    } else {
        // Rings: concentric noise rings
        vec2 c = uv - 0.5;
        float r = length(c);
        n = 0.5 + 0.5 * sin(r * 20.0 - t * 2.0 + value_noise(np) * 3.0);
    }

    n = clamp(n, 0.0, 1.0);
    vec3 col = noise_color * n * noise_amount;
    vec3 bg = background;
    col = max(bg, col);
    fragColor = vec4(col, 1.0);
}
