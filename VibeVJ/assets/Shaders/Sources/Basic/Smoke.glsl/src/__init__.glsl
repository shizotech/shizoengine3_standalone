// ==== Custom Uniform Controls ====

//@float min=0.01 max=2.0 value=0.5
uniform float smoke_density;

//@rgb value=(0.5,0.5,0.5)
uniform vec3 smoke_color;

//@float min=0.01 max=2.0 value=0.5
uniform float smoke_speed;

//@float min=0.0 max=2.0 value=0.8
uniform float turbulence;

//@float min=0.0 max=1.0 value=0.6
uniform float opacity;

float noise(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise_smooth(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x),
               mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), f.x), f.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * smoke_speed;

    // Smoke rises from bottom
    vec2 smoke_uv = uv;
    smoke_uv.y = 1.0 - smoke_uv.y;

    // Multiple noise layers for volumetric effect
    float n1 = noise_smooth(smoke_uv * 4.0 + vec2(time * 0.3, time * 0.5)) * turbulence;
    float n2 = noise_smooth(smoke_uv * 8.0 + vec2(n1 + time * 0.2, time * 0.4)) * 0.5;
    float n3 = noise_smooth(smoke_uv * 16.0 + vec2(n2, time * 0.6)) * 0.25;

    float smoke = (n1 + n2 + n3) * smoke_density;

    // Fade out at top and edges
    float fade_y = smoothstep(0.0, 0.3, smoke_uv.y) * smoothstep(1.0, 0.6, smoke_uv.y);
    float fade_x = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);

    float alpha = smoke * fade_y * fade_x * opacity;
    alpha = clamp(alpha, 0.0, 1.0);

    vec3 color = mix(vec3(0.0), smoke_color, alpha);

    fragColor = vec4(color, 1.0);
}