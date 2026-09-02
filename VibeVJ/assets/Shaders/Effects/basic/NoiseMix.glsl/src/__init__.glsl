// NoiseMix FX (FX5)
// Shadertoy format
// Mixes a selectable noise pattern into the input image (iChannel0).

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Choose the noise pattern
//@enum options=(Static, Perlin, Scanlines, TVNoise, Grain) value=0
uniform int noise_pattern;

// Amount of noise mixed into the image
//@slider min=0.0 max=1.0 value=0.3
uniform float noise_amount;

// Noise scale (fineness of the pattern)
//@slider min=0.1 max=4.0 value=1.0
uniform float noise_scale;

// Background fill
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

// ---- hash / gradient noise helpers ----
float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p.yx + vec2(34.23, 3.35));
    return fract((p.x + p.y) * p.x);
}

float perlin2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
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

    // base color from the input
    vec3 color = texture(iChannel0, uv).rgb;

    // Compute the selected noise pattern
    vec2 np = uv * iResolution.xy * noise_scale * 0.02 + vec2(iTime * 0.5, 0.0);
    float n;
    if (noise_pattern == 0) {
        // Static: per-pixel random each frame
        n = hash21(fragCoord * 0.5 + iTime);
    } else if (noise_pattern == 1) {
        // Perlin: smooth gradient noise
        n = perlin2(np);
    } else if (noise_pattern == 2) {
        // Scanlines: horizontal banding
        n = 0.5 + 0.5 * sin(fragCoord.y * 0.5 + iTime * 3.0);
    } else if (noise_pattern == 3) {
        // TV noise: fast flickering static
        n = hash21(fragCoord + iFrame * 0.01);
    } else {
        // Grain: fine temporal grain
        n = hash21(fragCoord * 2.0 + iTime);
    }

    // Mix the (grayscale) noise into the color
    vec3 noiseCol = vec3(n);
    vec3 outcol = mix(color, mix(color, noiseCol, 0.5), noise_amount);

    // Fallback background for out-of-bounds input
    vec3 bg = background;
    outcol = mix(bg, outcol, step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0));

    fragColor = vec4(outcol, 1.0);
}
