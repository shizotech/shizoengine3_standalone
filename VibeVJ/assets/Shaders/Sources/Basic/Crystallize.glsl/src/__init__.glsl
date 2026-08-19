
// ========================================
// CRYSTALLIZE - Fractal Crystal Pattern Generator
// VJ Shader for ShizoScript
// ========================================
// Generates complex crystalline/fractal geometric patterns
// using iterative mandelbrot-like mathematics with
// rotational symmetry and noise-based coloring.
// ========================================

//@float min=0.01 max=3.0 value=0.5
uniform float crystal_speed;

//@float min=0.1 max=5.0 value=1.0
uniform float crystal_zoom;

//@float min=-3.14159 max=3.14159 value=0.0
uniform float crystal_rotation;

//@float min=1.0 max=20.0 value=8.0
uniform float crystal_freq;

//@int min=1 max=6 value=4
uniform int crystal_complexity;

//@rgb value=(1.0,0.5,0.0)
uniform vec3 crystal_colors;

//@int min=3 max=12 value=6
uniform int crystal_symmetry;

//@float min=0.0 max=2.0 value=0.5
uniform float crystal_pulse;

// ========================================
// Utility Functions
// ========================================

// Simple hash-based pseudo-random
float hash(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D noise using hash
float noise2d(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion (fBm) for organic detail
float fbm(vec2 p, int octaves)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 6; i++)
    {
        if (i >= octaves) break;
        value += amplitude * noise2d(p * frequency);
        p *= 2.0;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

// ========================================
// Crystal Pattern Generation
// ========================================

// Iterated mandelbrot-style set with crystalline bailout
vec2 crystalIterate(vec2 z, vec2 c, int maxIter)
{
    float zLen2 = dot(z, z);
    float totalLen2 = zLen2;

    for (int i = 0; i < 256; i++)
    {
        if (i >= maxIter) break;

        // Crystal distortion: mix z^2 with higher powers based on iteration
        float power = 2.0 + 0.5 * sin(float(i) * 0.3);
        float r = sqrt(zLen2);
        float theta = atan(z.y, z.x);

        // Apply variable power in polar coordinates
        float newR = pow(r, power);
        float newTheta = theta * power;

        z = vec2(newR * cos(newTheta), newR * sin(newTheta));
        z += c;

        zLen2 = dot(z, z);
        totalLen2 = max(totalLen2, zLen2);

        if (totalLen2 > 256.0) break;
    }
    return z;
}

// Generate crystal domain warp
vec2 crystalWarp(vec2 uv, float t)
{
    float n1 = fbm(uv * 1.5 + vec2(t * 0.3, -t * 0.2), crystal_complexity);
    float n2 = fbm(uv * 1.5 + vec2(-t * 0.2, t * 0.4), crystal_complexity);

    return vec2(n1, n2) * 0.8;
}

// Apply rotational symmetry
vec2 applySymmetry(vec2 uv, int segments)
{
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    float segmentAngle = 6.2831853 / float(segments);
    float adjustedAngle = mod(angle, segmentAngle);

    // Mirror fold
    if (adjustedAngle > segmentAngle * 0.5)
    {
        adjustedAngle = segmentAngle - adjustedAngle;
    }

    return vec2(radius * cos(adjustedAngle), radius * sin(adjustedAngle));
}

// ========================================
// Coloring Functions
// ========================================

// Iridescent crystal color palette
vec3 crystalPalette(float t, vec3 colors)
{
    // Cosine-based color palette with crystal hues
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263, 0.416, 0.557);

    vec3 color = a + b * cos(6.2831853 * (c * t + d));
    color = mix(color, vec3(0.0), 0.15);

    // Add crystal-specific hue shift
    float hue = fract(t * 0.618033988 + 0.333); // golden ratio shift
    vec3 crystalHue = vec3(
        0.5 + 0.5 * cos(6.2831853 * (hue + 0.0)),
        0.5 + 0.5 * cos(6.2831853 * (hue + 0.33)),
        0.5 + 0.5 * cos(6.2831853 * (hue + 0.67))
    );

    color = mix(color, crystalHue, 0.4);
    color *= colors;

    return color;
}

// ========================================
// Main Image
// ========================================

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    uv -= 0.5;

    float time = iTime * crystal_speed;

    // Apply zoom and rotation
    float zoom = crystal_zoom;
    uv *= zoom;
    float rotAngle = crystal_rotation + time * 0.1;
    float cr = cos(rotAngle);
    float sr = sin(rotAngle);
    vec2 rotatedUV = vec2(
        uv.x * cr - uv.y * sr,
        uv.x * sr + uv.y * cr
    );

    // Domain warping for organic crystal growth
    vec2 warp = crystalWarp(rotatedUV * (crystal_freq * 0.3), time);

    // Iterated mandelbrot with symmetry
    vec2 z = rotatedUV + warp * 0.5;
    vec2 c = rotatedUV * 1.5;
    vec2 result = crystalIterate(z, c, crystal_complexity * 12 + 20);

    // Compute escape radius for smooth coloring
    float iter = float(crystal_complexity * 12 + 20);
    float log_zn = log(dot(result, result)) * 0.5;
    float nu = log(log_zn / log(2.0)) / log(2.0);
    iter -= nu;

    // Smooth normalized value
    float smoothVal = iter / 60.0;
    smoothVal = fract(smoothVal);

    // Apply symmetry to the UV space for pattern folding
    vec2 symUV = applySymmetry(rotatedUV, crystal_symmetry);
    float symPattern = fbm(symUV * crystal_freq * 0.8 + time * 0.5, crystal_complexity);

    // Pulse effect
    float pulse = sin(time * 3.14159) * crystal_pulse * 0.5 + 0.5;

    // Combine layers
    float crystalCore = smoothVal * (0.6 + 0.4 * pulse);
    float crystalEdge = 1.0 - smoothstep(0.0, 0.5, length(result) - 4.0);
    crystalEdge *= 0.3 + 0.7 * pulse;

    float noiseDetail = fbm(rotatedUV * crystal_freq + time * 0.7, crystal_complexity);
    float crystalStructure = crystalCore + crystalEdge + noiseDetail * 0.2;

    // Color the pattern
    vec3 color = crystalPalette(crystalStructure + time * 0.1, crystal_colors);

    // Add glow to bright areas
    float brightness = length(color);
    vec3 glow = color * brightness * 0.5;

    color += glow;
    color *= 0.8 + 0.2 * symPattern;

    // Final tone mapping
    color = 1.0 - exp(-color * 1.5);

    fragColor = vec4(color, 1.0);
}
