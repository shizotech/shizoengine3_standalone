// FX2 LayeredDistort - Pass 2 (COMPOSITE + BLUR)
// Shadertoy format
// Consumes the distorted output of pass 1 (auto-bound to the sampler 'layer1'),
// then softens it with a small separable-ish box blur and composites over a background.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded input from the previous (distort) pass, auto-bound by name
uniform sampler2D layer1;

// Blur amount applied within each cell/form (0 = sharp, higher = softer)
//@slider min=0.0 max=1.0 value=0.3
uniform float blur_amount;

// Number of blur taps (higher = smoother but costlier)
//@int min=2 max=8 value=4
uniform int blur_taps;

// Strength of the final composite over the background
//@slider min=0.0 max=1.0 value=1.0
uniform float composite;

// Background fill
//@rgb value=(0.03,0.03,0.06)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Average the distorted layer with a small box blur
    vec3 acc = vec3(0.0);
    float radius = blur_amount * 4.0; // in pixels
    float count = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(x, y) * radius / iResolution.xy;
            // Only count taps within the chosen radius window
            if (abs(float(x)) <= blur_taps && abs(float(y)) <= blur_taps) {
                acc += texture(layer1, uv + off).rgb;
                count += 1.0;
            }
        }
    }
    vec3 blurred = (count > 0.0) ? acc / count : texture(layer1, uv).rgb;

    // Composite blurred result over the background
    vec3 outcol = mix(background, blurred, composite);
    fragColor = vec4(outcol, 1.0);
}
