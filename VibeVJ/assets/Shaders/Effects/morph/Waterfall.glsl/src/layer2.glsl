// FX3 Waterfall - Pass 2 (LAYERS + BLUR)
// Shadertoy format
// Takes the base flow (layer1), then stacks up to N layered, blurred
// copies of it to build up a richer, softer waterfall.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded output of the base-flow pass, auto-bound by name
uniform sampler2D layer1;

// Number of stacked layers
//@int min=1 max=6 value=3
uniform int layer_count;

// Per-layer blur amount (0 = sharp)
//@slider min=0.0 max=1.0 value=0.4
uniform float layer_blur;

// Number of blur taps
//@int min=2 max=8 value=4
uniform int blur_taps;

// Background colour
//@rgb value=(0.04,0.05,0.10)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Base (sharp) layer
    vec3 acc = texture(layer1, uv).rgb;

    // Stack additional blurred layers with increasing blur radius
    for (int i = 1; i < 6; i++) {
        if (i >= layer_count) break;
        float radius = layer_blur * 3.0 * float(i);
        vec3 sum = vec3(0.0);
        float cnt = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 off = vec2(x, y) * radius / iResolution.xy;
                if (abs(float(x)) <= blur_taps && abs(float(y)) <= blur_taps) {
                    sum += texture(layer1, uv + off).rgb;
                    cnt += 1.0;
                }
            }
        }
        vec3 blurred = (cnt > 0.0) ? sum / cnt : acc;
        acc = max(acc, blurred); // additive-ish layering via max
    }

    vec3 bg = background;
    vec3 outcol = max(bg, acc);
    fragColor = vec4(outcol, 1.0);
}
