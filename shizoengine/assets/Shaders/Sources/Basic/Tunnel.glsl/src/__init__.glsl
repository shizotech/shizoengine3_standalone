// ==== Custom Uniform Controls ====

//@float min=0.01 max=5.0 value=1.0
uniform float tunnel_speed;

//@float min=0.1 max=3.0 value=1.0
uniform float tunnel_zoom;

//@float min=-3.14 max=3.14 value=0.0
uniform float tunnel_twist;

//@int min=3 max=12 value=6
uniform int tunnel_sides;

//@rgb value=(0.0,1.0,1.0)
uniform vec3 tunnel_colors;

//@float min=0.1 max=10.0 value=3.0
uniform float tunnel_depth;

//@float min=0.0 max=2.0 value=1.0
uniform float tunnel_pulse;

//@float min=0.1 max=5.0 value=1.0
uniform float tunnel_rings;

// Hash function for pseudo-random values
float hash(vec2 p)
{
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float hash1(float n)
{
    return fract(sin(n) * 43758.5453123);
}

// Generate tunnel pattern based on polygon sides
vec3 tunnel_pattern(vec2 uv, float time)
{
    // Polar coordinates
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // Apply twist
    a += tunnel_twist * time * 0.1;

    // Scale and zoom
    r *= tunnel_zoom;

    // Depth effect - moving into tunnel
    float depth = r * tunnel_depth;
    float z = time * tunnel_speed * 0.5 + depth;

    // Polygon shaping via radial folding
    float side_angle = 6.28318 / float(tunnel_sides);
    a = mod(a, side_angle) - side_angle * 0.5;

    // Ring pattern
    float ring_freq = tunnel_rings * 3.0;
    float rings = sin(z * ring_freq) * 0.5 + 0.5;

    // Pulse effect
    float pulse = sin(time * tunnel_speed * 2.0) * tunnel_pulse * 0.5 + 0.5;

    // Tunnel walls - alternating bright/dark segments
    float wall_pattern = 0.0;
    float segment = floor(a * float(tunnel_sides) / 3.14159);
    wall_pattern = mod(segment, 2.0);

    // Edge highlight for polygon facets
    float facet_edge = abs(a) * float(tunnel_sides) * 0.3;
    facet_edge = smoothstep(0.15, 0.0, facet_edge);

    // Inner glow
    float inner_glow = pow(1.0 - r, 3.0) * pulse;

    // Spiral streaks inside tunnel
    float spiral = sin(a * float(tunnel_sides) + z * 2.0) * 0.5 + 0.5;
    spiral = pow(spiral, 2.0);

    // Combine all pattern elements
    float pattern = 0.0;
    pattern += rings * 0.4;
    pattern += wall_pattern * 0.3;
    pattern += facet_edge * 0.5;
    pattern += spiral * 0.2;
    pattern += inner_glow * 0.6;

    // Create repeating tunnel segments
    float segment_length = 3.14159 / ring_freq;
    float seg_pos = mod(z, segment_length);
    float seg_fade = smoothstep(0.0, 0.1, seg_pos) * smoothstep(segment_length, segment_length - 0.1, seg_pos);

    // Depth fog - fade distant segments
    float fog = exp(-r * 0.8);

    // Final pattern
    pattern *= seg_fade * fog;
    pattern = pow(pattern, 0.8) * pulse;

    // Color mapping
    vec3 col = vec3(0.0);
    col = mix(col, tunnel_colors, pattern);

    // Add color variation based on angle
    float hue = fract(a / 6.28318 + time * 0.02);
    vec3 hue_col;
    hue_col.r = sin(6.28318 * hue * 0.5 + 0.0) * 0.5 + 0.5;
    hue_col.g = sin(6.28318 * hue * 0.5 + 2.094) * 0.5 + 0.5;
    hue_col.b = sin(6.28318 * hue * 0.5 + 4.188) * 0.5 + 0.5;

    col = mix(col, col * hue_col, 0.3 * pulse);

    // Add subtle star-like particles in tunnel
    float star_field = 0.0;
    vec2 star_uv = uv * 20.0 + vec2(time * 0.1, -time * 0.05);
    float star_hash = hash(floor(star_uv));
    if (star_hash > 0.95)
    {
        vec2 star_pos = fract(star_uv) - 0.5;
        float star_dist = length(star_pos);
        float star_brightness = hash(floor(star_uv) + 123.456);
        float star_twinkle = sin(time * (1.0 + star_brightness * 5.0) + star_hash * 6.28) * 0.5 + 0.5;
        star_field += smoothstep(0.05, 0.0, star_dist) * star_brightness * star_twinkle;
    }
    col += vec3(star_field * 0.5);

    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 uv_orig = uv;

    // Normalize with aspect ratio correction
    uv.x = (uv.x - 0.5) * iResolution.x / iResolution.y + 0.5;
    vec2 uv_center = uv - 0.5;
    uv_center *= 1.0 / tunnel_zoom;

    float time = iTime * tunnel_speed;

    // Create tunnel effect
    vec3 tunnel_color = tunnel_pattern(uv_center, time);

    // Add outer vignette / barrel distortion
    float barrel = length(uv_orig - 0.5);
    barrel = pow(barrel, 2.0) * 0.3;
    float vignette = 1.0 - barrel;

    // Outer space / dark border
    vec3 outer_space = vec3(0.0, 0.0, 0.02) * (1.0 - vignette);

    // Combine
    vec3 final_color = mix(outer_space, tunnel_color, vignette);

    // Add bloom/glow to bright areas
    float brightness = length(final_color);
    vec3 bloom = final_color * smoothstep(0.5, 1.5, brightness) * 0.3;
    final_color += bloom;

    // Tone mapping
    final_color = final_color / (final_color + 0.5);

    // Gamma correction
    final_color = pow(final_color, vec3(0.95));

    fragColor = vec4(final_color, 1.0);
}
