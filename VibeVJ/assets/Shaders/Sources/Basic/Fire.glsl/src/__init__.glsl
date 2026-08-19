// ==== Custom Uniform Controls ====

//@float min=0.1 max=3.0 value=1.0
uniform float fire_intensity;

//@rgb value=(1.0,0.3,0.0)
uniform vec3 fire_color1;

//@rgb value=(1.0,0.8,0.1)
uniform vec3 fire_color2;

//@float min=0.0 max=3.0 value=1.0
uniform float turbulence;

//@float min=0.1 max=3.0 value=1.0
uniform float speed;

// Noise function for fire turbulence
float noise(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise_smooth(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * speed;

    // Fire simulation using noise and feedback-like effect
    vec2 fire_uv = uv;
    fire_uv.y = 1.0 - fire_uv.y; // Flip vertically

    // Base fire shape
    float fire_base = smoothstep(0.0, 0.3, fire_uv.y) * smoothstep(1.0, 0.7, fire_uv.y);

    // Multiple noise layers for turbulence
    float n1 = noise_smooth(fire_uv * 5.0 + time * 0.5) * turbulence;
    float n2 = noise_smooth(fire_uv * 10.0 + vec2(n1, time * 0.3)) * 0.5 * turbulence;
    float n3 = noise_smooth(fire_uv * 20.0 + vec2(n2, time * 0.7)) * 0.25 * turbulence;

    float fire_noise = n1 + n2 + n3;

    // Fire color based on height and noise
    float height_factor = fire_uv.y;
    vec3 color;

    if (height_factor > 0.8)
    {
        // Yellow/white top
        color = mix(fire_color2, vec3(1.0, 1.0, 0.9), height_factor - 0.8) * 2.0;
    }
    else if (height_factor > 0.4)
    {
        // Orange middle
        color = mix(fire_color1, fire_color2, (height_factor - 0.4) * 2.5);
    }
    else
    {
        // Red/dark bottom
        color = fire_color1 * (height_factor * 2.0);
    }

    // Apply noise distortion
    color += fire_noise * 0.3;
    color *= fire_intensity;

    // Add flickering effect
    float flicker = sin(time * 10.0) * 0.05 + sin(time * 15.3) * 0.03;
    color += flicker;

    fragColor = vec4(color, 1.0);
}