//@settings dtype=float32 format=rgba
// Thin-film interference iridescence shader
// Simulates soap bubble / oil slick rainbow colors

//@slider min=0.01 max=2.0 value=0.3
uniform float iri_speed;

//@float min=0.0 max=3.0 value=1.5
uniform float iri_intensity;

//@float min=0.0 max=2.0 value=0.5
uniform float iri_distortion;

//@float min=0.0 max=3.0 value=1.5
uniform float iri_saturation;

//@float min=0.0 max=2.0 value=1.0
uniform float iri_brightness;

//@enum options=(Circle, Gradient, Diamond, Mixed)
uniform int iri_pattern;

//@slider min=0.0 max=3.14 value=0.0
uniform float iri_color_shift;

//@slider min=0.0 max=2.0 value=1.0
uniform float iri_fresnel;

// Simple hash for pseudo-random values
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Simplex-like noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for organic distortion
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 4; i++) {
        v += amp * noise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
        p += vec2(1.7, 9.2);
    }
    return v;
}

// Compute thickness map based on pattern
float thickness_map(vec2 uv, float t) {
    float d = 0.0;

    if (iri_pattern == 0) {
        // Concentric circles
        float r = length(uv - 0.5);
        d = r + 0.1 * sin(r * 20.0 - t * 3.0);
    } else if (iri_pattern == 1) {
        // Gradient with warping
        d = uv.y + 0.2 * sin(uv.x * 5.0 + t);
        d += 0.1 * cos(uv.y * 3.0 - t * 2.0);
    } else if (iri_pattern == 2) {
        // Diamond pattern
        vec2 p = abs(uv - 0.5) * 2.0;
        d = max(p.x, p.y) + 0.15 * sin((p.x + p.y) * 15.0 + t * 2.0);
    } else {
        // Mixed - combine multiple effects
        float r = length(uv - 0.5);
        d = r * 0.5 + uv.y * 0.5;
        d += 0.2 * sin(r * 10.0 - t * 2.0);
        d += 0.1 * cos(uv.x * 8.0 + t);
    }

    // Add organic distortion
    if (iri_distortion > 0.0) {
        vec2 distorted_uv = uv + 0.1 * vec2(
            sin(t * 0.7 + uv.y * 5.0),
            cos(t * 0.5 + uv.x * 5.0)
        );
        d += iri_distortion * (fbm(distorted_uv * 3.0) - 0.5);
    }

    return d;
}

// Thin-film interference color computation
// Based on the model by N. Georgiev and A. Bruck
vec3 thin_film_colors(float thickness, float angle, float shift) {
    // Refractive index of the film (soap/oil)
    float n = 1.33;

    // Wavelengths for RGB (in meters * 1e-9 to keep manageable)
    vec3 lambda = vec3(650.0, 550.0, 450.0) * 1.0e-9;

    // Phase shift for each wavelength
    // phi = 4*pi*n*d*cos(theta) / lambda
    float cos_theta = clamp(sqrt(1.0 - (sin(angle) / n) * (sin(angle) / n)), 0.01, 1.0);

    vec3 phase = 4.0 * 3.14159265 * n * thickness * cos_theta / lambda;

    // Add wavelength-dependent shift
    phase += shift * 2.0 * 3.14159265;

    // Interference pattern: 1 + cos(phase) gives constructive/destructive
    vec3 interference = 0.5 + 0.5 * cos(phase);

    // Second order interference for more color richness
    vec3 interference2 = 0.5 + 0.5 * cos(phase * 2.0 + 1.0);

    // Combine for richer colors
    vec3 colors = mix(interference, interference2, 0.3);

    // Shift the colors
    colors.r = mix(colors.r, colors.b, shift * 0.5);

    return colors;
}

// Fresnel-like edge highlight
float fresnel_factor(vec2 uv, float t) {
    vec2 center = vec2(0.5, 0.5);
    float d = length(uv - center);

    // Edge glow increases toward edges
    float fresnel = pow(1.0 - d, 3.0);

    // Animate
    fresnel *= 0.5 + 0.5 * sin(t * 1.5);

    return fresnel;
}

// Ambient/diffuse component
vec3 ambient_color(vec2 uv, float t) {
    // Soft base color that varies across the surface
    float base = 0.5 + 0.3 * sin(uv.x * 3.0 + t * 0.5);
    base *= 0.5 + 0.3 * cos(uv.y * 2.0 - t * 0.3);

    return vec3(base * 0.3, base * 0.35, base * 0.4);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    float t = iTime * iri_speed;

    // Compute thickness map (the "film thickness" varies across surface)
    float thickness = thickness_map(uv, t);

    // Normalize thickness to a reasonable range for visible colors
    thickness = clamp(thickness * 0.000002, 0.0000001, 0.000005); // 100nm - 5000nm

    // Compute view angle based on position (fake normal mapping)
    // This simulates the angle of incidence
    vec2 center = vec2(0.5, 0.5);
    vec2 offset = uv - center;
    float angle = atan(offset.y, offset.x);
    float incidence = length(offset) * 2.0; // 0 at center, 1 at edges

    // Compute iridescent colors
    vec3 iridescent = thin_film_colors(thickness, incidence, iri_color_shift);

    // Apply saturation
    iridescent = mix(vec3(dot(iridescent, vec3(0.3, 0.59, 0.11))), iridescent, iri_saturation);

    // Apply intensity
    iridescent *= iri_intensity;

    // Add ambient color
    vec3 ambient = ambient_color(uv, t);
    vec3 color = mix(ambient * 0.3, iridescent, 0.8);

    // Apply fresnel edge highlight
    float fr = fresnel_factor(uv, t);
    vec3 highlight = vec3(1.0, 0.95, 0.9) * fr * iri_fresnel;
    color += highlight;

    // Brightness control
    color *= iri_brightness;

    // Add subtle shimmer
    float shimmer = 0.02 * sin(t * 5.0 + uv.x * 50.0) * sin(t * 3.0 + uv.y * 40.0);
    color += shimmer;

    // Gamma correction for pleasant appearance
    color = pow(clamp(color, 0.0, 1.0), vec3(0.9));

    fragColor = vec4(color, 1.0);
}
