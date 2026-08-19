// ==== Custom Uniform Controls ====

//@vec2 min=(0.01,0.01) max=(0.5,0.5) value=(0.1,0.1)
uniform vec2 checker_size;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 color1;

//@rgb value=(0.0,0.0,0.0)
uniform vec3 color2;

//@float min=0.01 max=3.0 value=0.5
uniform float animation_speed;

//@enum options=(Static, Wave, Spiral)
uniform int pattern;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * animation_speed;
    vec2 checker = floor(uv / checker_size);

    // Base checkerboard pattern
    float pattern_val = mod(checker.x + checker.y, 2.0);

    if (pattern == 1)
    {
        // Wave animation
        float wave = sin(uv.x * 10.0 + time * 2.0) * 0.5 + 0.5;
        pattern_val = mix(pattern_val, 1.0 - pattern_val, wave * 0.5);
    }
    else if (pattern == 2)
    {
        // Spiral animation
        float dist = length(uv - 0.5);
        float spiral = sin(dist * 20.0 - time * 3.0) * 0.5 + 0.5;
        pattern_val = mix(pattern_val, 1.0 - pattern_val, spiral);
    }

    vec3 color = mix(color2, color1, pattern_val);

    fragColor = vec4(color, 1.0);
}