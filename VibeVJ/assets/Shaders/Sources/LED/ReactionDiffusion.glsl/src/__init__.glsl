//@settings dtype=float32 format=rgba

// --- Reaction-diffusion (Gray-Scott): the picture ---
// The simulation runs in pass A (A.glsl, chemical A in R, B in G). This first pass is the output of the generator:
// where B gathers it draws the foreground colour.

//@rgb value=(1.0, 0.6, 0.15)
uniform vec3 color_fg;

//@rgb value=(0.02, 0.0, 0.08)
uniform vec3 color_bg;

//@slider min=0.5 max=3.0 value=1.5
uniform float contrast;

//@slider min=0.2 max=3.0 value=1.0
uniform float gamma;

// The simulation state: bound to pass A by its name
uniform sampler2D A;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float b = texture(A, uv).g;

    float pattern = clamp(smoothstep(0.0, 0.5, b) * contrast, 0.0, 1.0);
    vec3 col = mix(color_bg, color_fg, pattern);
    col = pow(max(col, vec3(0.0)), vec3(1.0 / max(gamma, 0.1)));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
