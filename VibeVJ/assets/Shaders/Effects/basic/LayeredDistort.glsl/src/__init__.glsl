// FX2 LayeredDistort - Entry / Final Pass (MAIN)
// Shadertoy format
// Final pass: picks between the sharp distorted output (layer1) and the
// blurred+composited output (layer2).

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded outputs of the previous passes (auto-bound by name)
uniform sampler2D layer1;
uniform sampler2D layer2;

// Use the blurred+composited output
//@slider min=0.0 max=1.0 value=1.0
uniform float use_blur;

// Final brightness
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // mix between sharp (layer1) and blurred (layer2)
    vec3 sharp = texture(layer1, uv).rgb;
    vec3 blurred = texture(layer2, uv).rgb;
    vec3 color = mix(sharp, blurred, use_blur);

    color *= brightness;
    fragColor = vec4(color, 1.0);
}
