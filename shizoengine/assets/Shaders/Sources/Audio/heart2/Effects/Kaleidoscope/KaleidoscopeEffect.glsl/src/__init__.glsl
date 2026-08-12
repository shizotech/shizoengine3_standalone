// ==== Custom Uniform Controls ====

//@int min=2 max=12 value=6
uniform int kaleido_segments;

//@float min=-3.14159 max=3.14159 value=0.0
uniform float kaleido_angle;

//@float min=0.01 max=2.0 value=0.5
uniform float kaleido_speed;

//@float min=0.0 max=1.0 value=0.8
uniform float input_mix;

//@enum options=(Single, Double, Triple)
uniform int mirror_mode;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float radius = length(delta);
    float angle = atan(delta.y, delta.x) + kaleido_angle + iTime * kaleido_speed;

    // Kaleidoscope segment wrapping
    float segment_angle = 6.283185 / float(kaleido_segments);
    angle = mod(angle, segment_angle);

    // Mirror based on mode
    if (mirror_mode == 0)
    {
        // Single mirror
        angle = abs(angle - segment_angle * 0.5);
    }
    else if (mirror_mode == 1)
    {
        // Double mirror
        angle = abs(angle - segment_angle * 0.5);
        angle = abs(angle - segment_angle * 0.25);
    }
    else if (mirror_mode == 2)
    {
        // Triple mirror
        angle = abs(angle - segment_angle * 0.5);
        angle = abs(angle - segment_angle * 0.25);
        angle = abs(angle - segment_angle * 0.125);
    }

    // Convert back to Cartesian
    vec2 kaleido_uv = center + vec2(
        radius * cos(angle),
        radius * sin(angle)
    );

    // Sample input
    vec4 kaleido_input = texture2D(iChannel0, kaleido_uv);

    // Sample original for mix
    vec4 original = texture2D(iChannel0, uv);

    // Mix kaleidoscope with original input
    vec3 color = mix(original.rgb, kaleido_input.rgb, input_mix);

    // Add subtle color shift based on angle
    float hue_shift = sin(angle * 3.0 + iTime) * 0.1;
    color.r += hue_shift;
    color.b -= hue_shift;
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, mix(original.a, kaleido_input.a, input_mix));
}