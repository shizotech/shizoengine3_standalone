//@settings dtype=float32 format=rgba

//@int min=1 max=12 value=5
uniform int ball_count;

//@slider min=0.0 max=3.0 value=1.5
uniform float sensitivity;

//@slider min=0.0 max=2.0 value=1.0
uniform float glow;

//@rgb value=(0.3,0.6,1.0)
uniform vec3 ball_color;

// Cabbibo's HSV -> RGB (inlined helper, matching existing audio shaders)
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Simple deterministic hash for stable per-ball variation
float hash11(float n)
{
    return fract(sin(n * 12.9898) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Centered, aspect-corrected coordinates
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Overall audio level drives the central ball's radius/energy
    float level = texture(iChannel2, vec2(0.5)).x;
    float energy = clamp(level * sensitivity, 0.0, 1.0);

    // Beat-aligned pulse (iTime is in beats)
    float beat = 0.5 + 0.5 * cos(iTime * 6.283185307);

    vec3 col = vec3(0.0);

    // --- Central glowing, morphing ball ---
    // Radius breathes with audio energy and beat
    float radius = 0.16 + 0.22 * energy + 0.03 * beat;
    float dist = length(p);
    // Soft glowing sphere: bright core fading out with a power falloff
    float core = pow(max(1.0 - dist / radius, 0.0), 3.0);
    col += ball_color * core * (1.0 + glow * (0.5 + energy));
    // Bright center highlight so the ball reads as a solid sphere
    float center = pow(max(1.0 - dist / (radius * 0.4), 0.0), 2.0);
    col += vec3(1.0) * center * 0.8 * (0.5 + 0.5 * beat);

    // --- Splitting/orbiting satellite balls ---
    int N = ball_count;
    for (int i = 0; i < 12; i++)
    {
        if (i >= N) break;
        float fi = float(i);
        // Orbit angle: rotates with beats, evenly spaced
        float a = iTime * 1.570796327 + (6.283185307 * fi / float(N));
        // Orbit radius scales with energy, with a per-ball stable offset
        float h = hash11(fi + 1.0);
        float orbitR = 0.5 + 0.5 * energy + 0.05 * (h - 0.5);
        vec2 pos = orbitR * vec2(cos(a), sin(a));
        // Satellite ball: smaller glowing ball, pulsing with the beat
        float satR = 0.045 + 0.03 * energy + 0.015 * beat;
        float sd = length(p - pos);
        float satGlow = pow(max(1.0 - sd / satR, 0.0), 3.0);
        // Per-ball hue for a colorful milkdrop feel
        vec3 satCol = hsv2rgb(vec3(fract(0.15 * fi + 0.5), 0.85, 1.0));
        col += satCol * satGlow * (1.0 + glow * energy) * (0.7 + 0.3 * beat);
    }

    // Faint ambient pulse so the scene stays alive between hits
    col += ball_color * (0.015 + 0.03 * beat);

    fragColor = vec4(col, 1.0);
}
