// FX1 NoiseWash - Final Pass (MAIN)
// Shadertoy format
// Composites the cascaded output (noise wash with clean central shape)
// over the background.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded output of the shape-cut pass, auto-bound by name
uniform sampler2D layer2;

// Final brightness
//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;

// Background colour
//@rgb value=(0.05,0.04,0.08)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 col = texture(layer2, uv).rgb;
    col *= brightness;
    vec3 bg = background;
    col = max(bg, col);
    fragColor = vec4(col, 1.0);
}
