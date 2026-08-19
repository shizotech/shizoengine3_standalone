// ==== Custom Uniform Controls ====

//@float min=0.0 max=2.0 value=0.5
uniform float bloom_intensity;

//@float min=0.01 max=0.1 value=0.03
uniform float bloom_radius;

//@float min=0.0 max=1.0 value=0.5
uniform float bloom_threshold;

//@rgb value=(1.0,1.0,1.0)
uniform vec3 bloom_color;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texel_size = bloom_radius / iResolution.xy;

    // Sample input
    vec4 input_color = texture2D(iChannel0, uv);

    // Extract bright areas
    float brightness = dot(input_color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float bright_mask = smoothstep(bloom_threshold, bloom_threshold + 0.1, brightness);

    // Simple box blur for bloom
    vec4 bloom = vec4(0.0);
    float samples = 0.0;

    for (float x = -3.0; x <= 3.0; x += 1.0)
    {
        for (float y = -3.0; y <= 3.0; y += 1.0)
        {
            vec2 offset = vec2(x, y) * texel_size;
            vec4 sampled = texture2D(iChannel0, uv + offset);
            float sample_brightness = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));

            if (sample_brightness > bloom_threshold)
            {
                bloom += sampled;
                samples += 1.0;
            }
        }
    }

    if (samples > 0.0)
    {
        bloom /= samples;
    }

    // Combine input with bloom
    vec3 color = input_color.rgb + bloom.rgb * bloom_intensity * bright_mask;

    // Apply bloom color tint
    color = mix(color, color * bloom_color, bloom_intensity * 0.3);

    fragColor = vec4(color, input_color.a);
}