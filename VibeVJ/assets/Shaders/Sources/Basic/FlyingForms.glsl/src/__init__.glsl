// SFX1 FlyingForms - Final Pass (MAIN)
// Shadertoy format
// Picks between the two cascaded layers of flying forms and composites over the background.

//@settings dtype=float32 format=rgba rendersize=(1280,720)

// Cascaded layer output (auto-bound by name)
uniform sampler2D layer2;

// Background colour
//@rgb value=(0.02,0.02,0.05)
uniform vec3 background;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec3 layer_rgb = texture(layer2, uv).rgb;
    vec3 bg = background;
    vec3 outcol = max(bg, layer_rgb);

    fragColor = vec4(outcol, 1.0);
}
