// ClockWaves - Circular/Annular Wave Pattern with Interference
// VJ Shader - Generates radial sine waves with interference patterns
//
// Controls:
//   clockwave_speed     - Animation speed
//   clockwave_count     - Number of concentric wave rings
//   clockwave_freq      - Wave frequency (cycles per unit)
//   clockwave_colors    - Primary color multiplier
//   clockwave_decay     - How quickly waves fade with distance
//   clockwave_center_x  - Horizontal center offset (0-1)
//   clockwave_center_y  - Vertical center offset (0-1)
//   clockwave_interference - Multi-source interference strength

//@float min=0.01 max=5.0 value=1.0
uniform float clockwave_speed;

//@int min=1 max=20 value=8
uniform int clockwave_count;

//@float min=1.0 max=30.0 value=10.0
uniform float clockwave_freq;

//@rgb value=(0.5,0.0,1.0)
uniform vec3 clockwave_colors;

//@float min=0.0 max=1.0 value=0.5
uniform float clockwave_decay;

//@float min=0.0 max=1.0 value=0.5
uniform float clockwave_center_x;

//@float min=0.0 max=1.0 value=0.5
uniform float clockwave_center_y;

//@float min=0.0 max=2.0 value=0.5
uniform float clockwave_interference;

// Spherical linear interpolation helper
vec3 slerp_color(vec3 a, vec3 b, float t)
{
    return mix(a, b, t);
}

// Color palette based on angle and value
vec3 palette(float t)
{
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263, 0.416, 0.557);
    return a + b * cos(6.283185 * (c * t + d));
}

// Compute a single circular wave at given distance
float circular_wave(float dist, float phase, float freq)
{
    // Damped sine wave radiating outward
    float wave = sin(dist * freq - phase);
    // Smooth the wave with a subtle glow
    wave = wave * 0.5 + 0.5;
    // Sharpen with power for crisp rings
    wave = pow(wave, 2.0);
    return wave;
}

// Multi-source interference: sum of multiple wave centers
float interference_pattern(vec2 uv, vec2 center, float time, float speed, float count, float freq, float decay)
{
    float total = 0.0;

    // Primary center wave
    vec2 offset = uv - center;
    float dist = length(offset);

    // Multiple wave rings at different phases
    for (int i = 0; i < 20; i++)
    {
        if (i >= int(count))
            break;

        float ring_phase = float(i) * 0.5 + time * speed;
        float ring_freq = freq + float(i) * 1.5;
        float ring_decay = 1.0 - smoothstep(0.0, 1.5, dist) * decay;

        float wave = circular_wave(dist + float(i) * 0.15, ring_phase, ring_freq);
        total += wave * ring_decay;
    }

    return total;
}

// Animated secondary interference sources
float secondary_sources(vec2 uv, float time, float speed, float interStrength)
{
    if (interStrength < 0.01)
        return 0.0;

    float result = 0.0;

    // Orbiting wave sources
    for (int i = 0; i < 4; i++)
    {
        float angle = float(i) * 1.5708 + time * speed * 0.5;
        float orbit_r = 0.2 + 0.1 * sin(time * speed + float(i));
        vec2 src = vec2(cos(angle) * orbit_r, sin(angle) * orbit_r);
        src += 0.5; // offset to screen space

        vec2 offset = uv - src;
        float dist = length(offset);

        float wave = sin(dist * 15.0 - time * speed * 3.0 + float(i));
        wave = pow(max(wave, 0.0), 3.0);
        float falloff = 1.0 - smoothstep(0.0, 0.5, dist);

        result += wave * falloff;
    }

    return result * interStrength;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalized coordinates with aspect correction
    vec2 uv = fragCoord.xy / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    uv.x *= aspect;

    // Center in aspect-corrected coordinates
    vec2 center = vec2(clockwave_center_x * aspect, clockwave_center_y);

    float time = iTime * clockwave_speed;

    // Primary circular wave pattern
    float primary = interference_pattern(uv, center, time, clockwave_speed,
                                          float(clockwave_count), clockwave_freq,
                                          clockwave_decay);

    // Secondary interference sources (orbiting)
    float secondary = secondary_sources(uv, time, clockwave_speed, clockwave_interference);

    // Combine patterns
    float pattern = primary + secondary;

    // Color the pattern using a palette driven by distance and time
    float color_t = fract(length(uv - center) * 0.5 - time * 0.1);
    vec3 col = palette(color_t);

    // Apply user color multiplier
    col *= clockwave_colors;

    // Intensity mapping - bright rings on dark background
    float intensity = pow(pattern, 0.8);
    intensity = clamp(intensity, 0.0, 1.0);

    // Add subtle ambient glow at center
    float center_glow = exp(-length(uv - center) * 3.0) * 0.3;
    intensity += center_glow;

    // Final color with intensity modulation
    vec3 final_color = col * intensity;

    // Subtle vignette
    float vignette = 1.0 - smoothstep(0.3, 1.2, length(uv - center * vec2(aspect, 1.0)));
    final_color *= vignette * 0.5 + 0.5;

    fragColor = vec4(final_color, 1.0);
}
