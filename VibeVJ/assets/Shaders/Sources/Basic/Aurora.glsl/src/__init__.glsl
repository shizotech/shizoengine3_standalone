// ==== Custom Uniform Controls ====

//@float min=0.01 max=2.0 value=0.5
uniform float aurora_speed;

//@float min=0.0 max=2.0 value=1.0
uniform float aurora_intensity;

//@float min=0.1 max=2.0 value=0.8
uniform float aurora_width;

//@rgb value=(0.0,1.0,0.5)
uniform vec3 aurora_colors;

//@float min=1.0 max=15.0 value=5.0
uniform float aurora_frequency;

//@float min=-2.0 max=2.0 value=0.5
uniform float aurora_wind;

//@float min=0.0 max=1.0 value=0.5
uniform float aurora_streaks;

// --- Preset: Layer count ---
uniform int preset; // [layer_count] 1-5

// --- Preset: Color scheme ---
uniform int preset2; // [scheme] 0-Green 1-Purple 2-Rainbow

// --- Preset: Wave shape ---
uniform int preset3; // [wave_shape] 0-Sine 2-Square 1-Sawtooth

// --- Preset: Star count ---
uniform int preset4; // [star_count] 500 1000

// --- Preset: Aurora shape ---
uniform int preset5; // [aurora_shape] 0-Flat 1-Curve 2-Dome

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

// Aurora color palette based on angle
vec3 aurora_color(float angle, vec3 color_mult)
{
    // HSL-like color mixing for natural aurora look
    float h = fract(angle * 0.1 + 0.3); // green-cyan range

    vec3 col;
    col.r = sin(6.28318 * (h * 0.3 + 0.0)) * 0.5 + 0.5;
    col.g = sin(6.28318 * (h * 0.3 + 0.33)) * 0.8 + 0.2;
    col.b = sin(6.28318 * (h * 0.3 + 0.66)) * 0.3 + 0.1;

    col = mix(col, color_mult, 0.6);

    return col;
}

vec3 starfield(vec2 uv, int count)
{
    vec2 grid = floor(uv * float(count));
    vec2 fv = fract(uv * float(count)) - 0.5;

    float star = 0.0;

    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 sample_pos = (grid + neighbor) * 67.345 + 23.456;

            float brightness = hash(sample_pos);
            if (brightness > 0.97)
            {
                vec2 offset = neighbor - fv + vec2(hash(sample_pos + 934.345) - 0.5) * 0.3;
                float dist = length(offset);
                float twinkle = sin(iTime * (1.0 + hash(sample_pos + 567.89) * 3.0) + brightness * 6.28) * 0.5 + 0.5;
                star += smoothstep(0.1, 0.0, dist) * twinkle * (0.5 + brightness * 0.5);
            }
        }
    }

    return vec3(star);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 uv_orig = uv;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * aurora_speed;

    // Dark sky gradient
    float sky_grad = pow(1.0 - uv.y, 2.0);
    vec3 sky_color = mix(vec3(0.01, 0.01, 0.04), vec3(0.0, 0.0, 0.02), sky_grad);

    // Add stars
    int star_count = 500;
    if (preset == 1) star_count = 500;
    else if (preset == 2) star_count = 1000;
    else star_count = 500;

    // Adjust based on UV range for star density
    vec3 stars = starfield(uv * 3.0, star_count) * (1.0 - uv.y * 0.5);
    sky_color += stars;

    // Aurora curtains
    float layer_count = 3.0;
    if (preset == 0) layer_count = 1.0;
    else if (preset == 1) layer_count = 2.0;
    else if (preset == 2) layer_count = 3.0;
    else if (preset == 3) layer_count = 4.0;
    else layer_count = 5.0;

    vec3 aurora_total = vec3(0.0);

    for (float layer = 0.0; layer < layer_count; layer++)
    {
        float layer_y = 0.4 + layer * 0.08;
        float layer_offset = layer * 2.39; // golden angle offset for layer separation

        // Base curtain shape - wave across screen
        float wave_x = sin(uv.x * aurora_frequency + time * 0.5 + layer_offset) * 0.15;
        wave_x += sin(uv.x * aurora_frequency * 2.5 + time * 0.3 + layer_offset * 1.7) * 0.08;

        // Wind effect
        wave_x += aurora_wind * 0.1 * sin(time * 0.7 + layer);

        float curtain_center = layer_y + wave_x;

        // Vertical curtain profile - tall thin curtain
        float dy = uv.y - curtain_center;

        // Shape variations
        float curtain = 0.0;
        if (preset5 == 0)
        {
            // Flat curtain
            curtain = exp(-dy * dy / (0.04 + aurora_width * 0.02));
        }
        else if (preset5 == 1)
        {
            // Curved curtain
            float curve = sin(uv.x * 3.14159) * 0.1;
            curtain_center += curve;
            dy = uv.y - curtain_center;
            curtain = exp(-dy * dy / (0.03 + aurora_width * 0.015));
            curtain *= 1.0 + sin(uv.x * 5.0 + time * 0.5) * 0.2;
        }
        else
        {
            // Dome shape
            float curve = (1.0 - abs(uv.x - 0.5) * 2.0) * 0.15;
            curtain_center += curve;
            dy = uv.y - curtain_center;
            curtain = exp(-dy * dy / (0.05 + aurora_width * 0.025));
            curtain *= (1.0 - abs(uv.x - 0.5)) * 0.5 + 0.5;
        }

        // Streaks effect
        if (aurora_streaks > 0.0)
        {
            float streak_freq = 20.0 + layer * 5.0;
            float streak = 0.0;
            streak += sin(dy * streak_freq + time * 2.0 + layer) * 0.5 + 0.5;
            streak *= sin(uv.x * streak_freq * 0.5 + time + layer * 3.0) * 0.3 + 0.7;
            streak = pow(streak, 3.0);
            curtain += streak * aurora_streaks * 0.5;
        }

        // Perlin noise distortion for natural look
        float noise_offset = time * 0.1 + layer * 5.0;
        vec2 noise_uv = vec2(uv.x * 3.0 + noise_offset, time * 0.05);
        float n = fbm(noise_uv) - 0.5;

        // Horizontal distortion
        float horiz_distort = n * 0.1;
        curtain_center += horiz_distort;
        dy = uv.y - curtain_center;

        // Vertical noise for curtain texture
        vec2 noise_uv2 = vec2(uv.x * 8.0, uv.y * 4.0 + time * 0.2 + layer);
        float vert_noise = fbm(noise_uv2);
        curtain *= 0.6 + vert_noise * 0.4;

        // Edge softness
        float top_edge = smoothstep(0.75, 0.4, uv.y);
        float bottom_edge = smoothstep(0.15, 0.35, uv.y);
        curtain *= top_edge * bottom_edge;

        // Color based on angle/position
        float angle = uv.x + time * 0.05 + layer * 0.2;
        vec3 layer_color = aurora_color(angle, aurora_colors);

        // Add some color variation per layer
        layer_color.b += layer * 0.05;
        layer_color.r += sin(layer * 1.5) * 0.1;

        // Apply color scheme
        if (preset2 == 0)
        {
            // Green tint
            layer_color = vec3(layer_color.g * 0.3, layer_color.g, layer_color.g * 0.7);
        }
        else if (preset2 == 1)
        {
            // Purple tint
            layer_color = vec3(layer_color.b * 0.8, layer_color.g * 0.2, layer_color.b);
        }
        else
        {
            // Rainbow
            layer_color.r += sin(layer * 2.0 + time) * 0.2;
            layer_color.g += sin(layer * 2.0 + time + 2.094) * 0.2;
            layer_color.b += sin(layer * 2.0 + time + 4.188) * 0.2;
        }

        // Intensity falloff per layer
        float layer_intensity = 1.0 / (1.0 + layer * 0.3);
        layer_intensity *= aurora_intensity;

        aurora_total += curtain * layer_color * layer_intensity;
    }

    // Add glow/bloom effect
    float glow = length(aurora_total);
    vec3 glow_color = aurora_total * (glow * 0.5 + 0.2);

    // Combine everything
    vec3 final_color = sky_color + aurora_total + glow_color;

    // Subtle vignette
    float vignette = 1.0 - length(uv_orig - 0.5) * 0.5;
    final_color *= vignette;

    // Gamma correction
    final_color = pow(final_color, vec3(0.9));

    fragColor = vec4(final_color, 1.0);
}
