// ==== Custom Uniform Controls ====

//@int min=2 max=16 value=6
uniform int kaleido_segments;

//@float min=-3.14159 max=3.14159 value=0.0
uniform float kaleido_rotation;

//@float min=0.01 max=2.0 value=0.5
uniform float kaleido_speed;

//@rgb value=(1.0,0.5,0.0)
uniform vec3 kaleido_colors;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    uv -= 0.5;

    float time = iTime * kaleido_speed;

    // Convert to polar coordinates
    float angle = atan(uv.y, uv.x) + kaleido_rotation + time;
    float radius = length(uv);

    // Mirror and wrap angle for kaleidoscope segments
    float segment_angle = 6.283185 / float(kaleido_segments);
    angle = mod(angle, segment_angle);
    angle = abs(angle - segment_angle * 0.5);

    // Convert back to Cartesian
    vec2 mirrored_uv;
    mirrored_uv.x = radius * cos(angle);
    mirrored_uv.y = radius * sin(angle);
    mirrored_uv += 0.5;

    // Generate colorful patterns
    float pattern1 = sin(mirrored_uv.x * 10.0 + time) * 0.5 + 0.5;
    float pattern2 = sin(mirrored_uv.y * 8.0 - time * 0.7) * 0.5 + 0.5;
    float pattern3 = sin((mirrored_uv.x + mirrored_uv.y) * 6.0 + time * 1.3) * 0.5 + 0.5;

    // Radial color gradient
    float dist = length(mirrored_uv - 0.5);
    float color_cycle = fract(dist * 3.0 - time * 0.2);

    vec3 color;
    if (color_cycle < 0.333)
    {
        color = mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), color_cycle * 3.0);
    }
    else if (color_cycle < 0.666)
    {
        color = mix(vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), (color_cycle - 0.333) * 3.0);
    }
    else
    {
        color = mix(vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), (color_cycle - 0.666) * 3.0);
    }

    color *= kaleido_colors;
    color *= 0.5 + 0.5 * (pattern1 + pattern2 + pattern3) / 3.0;

    fragColor = vec4(color, 1.0);
}