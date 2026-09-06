//@settings dtype=float32 format=rgba

//@rgb value=(1.0, 0.6, 0.15)
uniform vec3 color_fg;

//@rgb value=(0.02, 0.0, 0.08)
uniform vec3 color_bg;

//@slider min=0.5 max=3.0 value=1.5
uniform float contrast;

//@slider min=0.2 max=3.0 value=1.0
uniform float gamma;

// Auto-binds to the __init__.glsl pass output (sim state) via the special input name 'main_image'
uniform sampler2D main_image;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec4 s = texture(main_image, uv, 0.0);
    float A = s.r;
    float B = s.g;

    // Where B (the B chemical) accumulates -> foreground
    float pattern = smoothstep(0.0, 0.5, B) * contrast;
    vec3 col = mix(color_bg, color_fg, clamp(pattern, 0.0, 1.0));

    // Gamma correction (safe form)
    float g = 1.0 / max(gamma, 0.1);
    vec3 invGamma = vec3(g);
    col = pow(max(col, vec3(0.0)), invGamma);

    fragColor = vec4(col, 1.0);
}
