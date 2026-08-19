// ==== Custom Uniform Controls ====

//@float min=0.0 max=2.0 value=0.5
uniform float neon_intensity;

//@float min=0.01 max=0.1 value=0.03
uniform float neon_radius;

//@rgb value=(0.0,1.0,1.0)
uniform vec3 neon_color;

//@float min=0.0 max=1.0 value=0.5
uniform float neon_threshold;

//@float min=0.0 max=1.0 value=0.7
uniform float neon_blend;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel_size = neon_radius / iResolution.xy;

    // Sample input
    vec4 input = texture2D(iChannel0, uv);
    float brightness = dot(input.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Detect edges using simple difference
    float edge_x = abs(input.r - texture2D(iChannel0, uv + vec2(texel_size.x, 0.0)).r);
    float edge_y = abs(input.g - texture2D(iChannel0, uv + vec2(0.0, texel_size.y)).g);
    float edge = max(edge_x, edge_y);

    // Neon glow effect
    vec4 glow = vec4(0.0);
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * texel_size;
            vec4 sampled = texture2D(iChannel0, uv + offset);
            float sample_bright = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));

            if (sample_bright > neon_threshold) {
                glow += sampled * vec4(neon_color, 1.0);
            }
        }
    }
    glow /= 25.0;

    // Combine edge detection with glow
    vec3 color = input.rgb;
    color += glow.rgb * neon_intensity * step(neon_threshold, brightness);
    color += neon_color * edge * neon_intensity * 2.0;

    color = mix(input.rgb, color, neon_blend);

    fragColor = vec4(color, input.a);
}