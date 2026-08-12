// ==== Custom Uniform Controls ====

//@float min=0.01 max=3.0 value=0.5
uniform float spiral_speed;

//@float min=0.0 max=2.0 value=0.5
uniform float spiral_intensity;

//@enum options=(Clockwise, Counter-Clockwise)
uniform int spiral_direction;

//@int min=1 max=10 value=3
uniform int spiral_points;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    float time = iTime * spiral_speed;
    float direction = (spiral_direction == 0) ? 1.0 : -1.0;

    // Spiral transform
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float dist = length(delta);
    float angle = atan(delta.y, delta.x);

    // Apply spiral distortion
    float spiral_angle = angle + direction * dist * spiral_intensity * 5.0 + time;
    float spiral_radius = dist + sin(dist * 10.0 - time * 2.0) * spiral_intensity * 0.05;

    vec2 spiral_uv = center + vec2(
        cos(spiral_angle) * spiral_radius,
        sin(spiral_angle) * spiral_radius
    );

    // Add multiple spiral points
    for (int i = 1; i < spiral_points; i++) {
        float i_f = float(i);
        float extra_angle = spiral_angle + i_f * 6.283185 / float(spiral_points);
        float extra_radius = spiral_radius * (1.0 + 0.1 * sin(time + i_f));
        vec2 extra_uv = center + vec2(
            cos(extra_angle) * extra_radius,
            sin(extra_angle) * extra_radius
        );

        float blend = 1.0 / (1.0 + i_f * 0.5);
        spiral_uv = mix(spiral_uv, extra_uv, blend * 0.3);
    }

    fragColor = texture2D(iChannel0, spiral_uv);

    if (fragColor.a == 0.0)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}