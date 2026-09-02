//@settings dtype=float32 format=rgba

// ==== Custom Uniform Controls ====

//@slider min=0.0 max=1.0 value=0.6
uniform float smoothness;

//@float min=0.5 max=8.0 value=2.0
uniform float scale;

//@int min=1 max=8 value=4
uniform int layer_count;

//@slider min=0.0 max=1.0 value=0.5
uniform float layer_random;

//@rgb value=(0.9, 0.92, 1.0)
uniform vec3 foreground_color;

//@rgb value=(0.05, 0.1, 0.25)
uniform vec3 background_color;

//@button
uniform bool grid_fill = false;

// --- Noise helpers (copied pattern from Basic/Aurora.glsl) ---

float hash(vec2 p)
{
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 6; i++)
    {
        value += amplitude * noise(p * frequency);
        frequency *= 2.03;
        amplitude *= 0.48;
    }
    return value;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect_ratio = iResolution.x / iResolution.y;

    // Aspect-corrected coordinates so clouds keep a consistent size
    vec2 uv_a = vec2(uv.x * aspect_ratio, uv.y);

    // iTime is in beats (1.0 = 1 beat); keep motion beat-synced
    float time = iTime;

    // Subtle sky gradient background (top lighter, bottom darker)
    vec3 bg = mix(background_color * 0.5, background_color, uv.y);

    // Optional subtle grid/raster fill over the background
    if (grid_fill)
    {
        vec2 grid_uv = uv * vec2(24.0 * aspect_ratio, 12.0);
        vec2 g = abs(fract(grid_uv) - 0.5);
        float line = 1.0 - max(smoothstep(0.42, 0.5, g.x), smoothstep(0.42, 0.5, g.y));
        bg = mix(bg, bg + foreground_color * 0.08, line);
    }

    vec3 clouds = vec3(0.0);

    for (int layer = 0; layer < 8; layer++)
    {
        if (layer >= layer_count)
        {
            break;
        }

        // Layer distribution:
        // layer_random=0 -> strictly even vertical distribution
        // layer_random=1 -> deterministically "random" offsets per layer
        float even_offset = float(layer) / float(max(layer_count - 1, 1));
        float rand_offset = hash(vec2(float(layer) * 13.0 + 0.71, 4.01));
        float y_off = mix(even_offset, rand_offset, clamp(layer_random, 0.0, 1.0));

        // Parallax: each layer slides horizontally at a different speed,
        // back layers slow, front layers faster. Beat-based speed.
        float speed = 0.05 + 0.07 * float(layer);
        float x_shift = -mod(time * speed, 2.0) - 2.0;

        vec2 p = vec2(uv_a.x + x_shift, uv_a.y + (y_off - 0.5) * 0.9);

        // Sample FBM noise; smoothness lowers the effective frequency
        // (softer, lower-frequency clouds) for softer edges.
        float edge_soft = mix(1.0, 0.35, clamp(smoothness, 0.0, 1.0));
        float n = fbm(p * (scale * edge_soft));

        // Shape the noise into fluffy cloud puffs
        float puff = smoothstep(0.35, 0.75, n);

        // Slight per-layer vertical band mask so layers don't fill the whole screen
        float band = smoothstep(0.0, 0.15, uv.y - (y_off - 0.5) * 0.35) * smoothstep(1.0, 0.85, uv.y - (y_off - 0.5) * 0.35);

        // Intensity falloff: front layers (higher index) are stronger
        // (mirrors Aurora's 1/(1 + layer*0.3) falloff, inverted)
        float layer_intensity = 0.25 + 0.85 * (float(layer) / float(max(layer_count - 1, 1)));

        // Slight per-layer color variation for depth
        vec3 layer_color = foreground_color;
        layer_color = mix(layer_color, layer_color * vec3(0.85, 0.9, 1.0), 1.0 - float(layer) / float(max(layer_count - 1, 1)));

        clouds += puff * band * layer_color * layer_intensity;
    }

    vec3 final_color = bg + clouds;
    fragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
