//@settings dtype=float32 format=rgba

// --- Two-color render pass ---
// Reads the simulation state (u in R, v in G) from the previous pass via
// 'main_image' (auto-binds to the __init__ pass) and maps the v-field to a
// dark background / bright foreground palette with contrast + gamma control.

//@rgb value=(0.02, 0.02, 0.05)
uniform vec3 background_color;

//@rgb value=(0.3, 0.9, 1.0)
uniform vec3 foreground_color;

//@slider min=0.5 max=3.0 value=1.5
uniform float contrast;

//@slider min=0.2 max=3.0 value=1.0
uniform float gamma;

// Auto-binds to the __init__ pass output (the sim state).
uniform sampler2D main_image;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec4 s = texture(main_image, uv);
    float v = s.g;

    // Map the B chemical (v) to the foreground; low v stays background.
    float pattern = smoothstep(0.0, 0.5, v) * contrast;
    vec3 col = mix(background_color, foreground_color, clamp(pattern, 0.0, 1.0));

    // Gamma correction (safe form: denominator guarded with max()).
    float g = 1.0 / max(gamma, 0.1);
    vec3 invGamma = vec3(g);
    col = pow(max(col, vec3(0.0)), invGamma);

    fragColor = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
