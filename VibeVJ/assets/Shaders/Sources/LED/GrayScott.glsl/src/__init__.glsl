//@settings dtype=float32 format=rgba

// --- Gray-Scott reaction-diffusion: the picture ---
// The simulation runs in pass A (A.glsl, u in R, v in G). This first pass is the output of the generator: it maps the
// v field to a background / foreground colour with contrast and gamma.

//@rgb value=(0.02, 0.02, 0.05)
uniform vec3 background_color;

//@rgb value=(0.3, 0.9, 1.0)
uniform vec3 foreground_color;

//@slider min=0.5 max=3.0 value=1.5
uniform float contrast;

//@slider min=0.2 max=3.0 value=1.0
uniform float gamma;

// The simulation state: bound to pass A by its name
uniform sampler2D A;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float v = texture(A, uv).g;

    float pattern = clamp(smoothstep(0.0, 0.5, v) * contrast, 0.0, 1.0);
    vec3 col = mix(background_color, foreground_color, pattern);
    col = pow(max(col, vec3(0.0)), vec3(1.0 / max(gamma, 0.1)));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
