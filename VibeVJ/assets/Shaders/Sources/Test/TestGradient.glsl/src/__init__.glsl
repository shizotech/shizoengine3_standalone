//@settings dtype=float32 format=rgba
//@slider min=0.0 max=4.0 value=1.0
uniform float speed;

//@slider min=0.0 max=2.0 value=0.3
uniform float thickness;

//@rgb value=(1.0, 0.4, 0.1)
uniform vec3 color_a;

//@rgb value=(0.1, 0.5, 1.0)
uniform vec3 color_b;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 p = uv - vec2(0.5);

    float t = iTime * speed;

    // Animated radial rings
    float d = length(p);
    float angle = atan(p.y, p.x);
    float rings = sin(d * 30.0 - t * 6.2831) * 0.5 + 0.5;
    float spiral = sin(angle * 3.0 + t * 3.1415 - d * 10.0) * 0.5 + 0.5;

    float mixv = clamp(rings * (1.0 - thickness) + spiral * thickness, 0.0, 1.0);
    vec3 col = mix(color_a, color_b, mixv);

    // Soft vignette
    col *= 1.0 - smoothstep(0.35, 0.75, d) * 0.5;

    fragColor = vec4(col, 1.0);
}
