// ==== Custom Uniform Controls ====

//@float min=0.0 max=2.0 value=0.5
uniform float distortion_amount;

//@float min=0.1 max=10.0 value=3.0
uniform float distortion_frequency;

//@float min=0.01 max=3.0 value=1.0
uniform float distortion_speed;

//@enum options=(Radial, Ripple, Twist)
uniform int distortion_type;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 distorted_uv;

    if (distortion_type == 0)
    {
        // Radial distortion
        vec2 center = vec2(0.5);
        vec2 delta = uv - center;
        float dist = length(delta);
        float angle = atan(delta.y, delta.x);

        float warp = sin(dist * distortion_frequency - iTime * distortion_speed) * distortion_amount;
        distorted_uv = center + delta * (1.0 + warp * 0.5);
    }
    else if (distortion_type == 1)
    {
        // Ripple distortion
        vec2 center = vec2(0.5);
        float dist = length(uv - center);
        float angle = atan(uv.y - 0.5, uv.x - 0.5);

        float ripple = sin(dist * 20.0 - iTime * distortion_speed * 3.0) * distortion_amount;
        distorted_uv = uv + vec2(cos(angle), sin(angle)) * ripple * 0.05;
    }
    else if (distortion_type == 2)
    {
        // Twist distortion
        vec2 center = vec2(0.5);
        vec2 delta = uv - center;
        float dist = length(delta);

        float twist_angle = sin(dist * distortion_frequency - iTime * distortion_speed) * distortion_amount;
        float c = cos(twist_angle);
        float s = sin(twist_angle);

        distorted_uv = center + vec2(
            delta.x * c - delta.y * s,
            delta.x * s + delta.y * c
        );
    }

    distorted_uv.x *= iResolution.x / iResolution.y;

    fragColor = texture2D(iChannel0, distorted_uv);

    if (fragColor.a == 0.0)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}