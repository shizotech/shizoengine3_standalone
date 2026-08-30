//@settings dtype=float32 format=rgba

//@int min=2 max=16 value=8
uniform int ring_count;

//@slider min=0.0 max=3.0 value=1.5
uniform float sensitivity;

//@slider min=0.0 max=2.0 value=1.0
uniform float ring_width;

//@slider min=0.5 max=3.0 value=1.5
uniform float expansion;

//@rgb value=(0.3,0.6,1.0)
uniform vec3 ring_color;

// Cabbibo's HSV -> RGB (inlined helper, matching existing audio shaders)
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Centered, aspect-corrected coordinates
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float dist = length(p);

    // Per-frequency audio drives the ring at this radius:
    // low frequencies -> inner rings, high frequencies -> outer rings.
    // iChannel2 is the frequency spectrum (1024 bins packed into a texture).
    float binU = clamp(dist / 1.2, 0.0, 0.999);
    float freq = clamp(texture(iChannel2, vec2(binU, 0.5)).x * sensitivity, 0.0, 1.0);

    // Overall level for the global energy floor
    float level = clamp(texture(iChannel2, vec2(0.5)).x * sensitivity, 0.0, 1.0);

    // Beat-aligned base pulse (iTime is in beats)
    float beat = 0.5 + 0.5 * cos(iTime * 6.283185307);

    vec3 col = vec3(0.0);

    // --- Concentric expanding rings ---
    // Each ring i expands outward; expansion speed is scaled by audio energy
    // and offset in time by its index so rings flow outward continuously.
    int N = ring_count;
    for (int i = 0; i < 16; i++)
    {
        if (i >= N) break;
        float fi = float(i);
        // Phase offset per ring so they are evenly staggered
        float phase = (iTime * expansion + fi / float(N)) - (0.3 + 0.7 * freq);
        float r = abs(fract(phase) * 1.4 - 0.4);
        // Distance from the ring of radius r to the current point
        float d = dist - r;
        // Sharp ring via smooth falloff; width is user-controllable
        float w = 0.012 * ring_width * (1.0 + 0.5 * freq);
        float ring = smoothstep(w, 0.0, abs(d));
        // Ring color cycles hue per-ring and brightens with local frequency + beat
        vec3 c = hsv2rgb(vec3(fract(0.07 * fi + 0.6), 0.7, 1.0));
        // Mix toward the user-chosen base color for a cohesive milkdrop look
        vec3 ringCol = mix(ring_color, c, 0.5);
        // Intensity driven by the local per-frequency amplitude
        col += ringCol * ring * (0.35 + 0.65 * freq) * (0.7 + 0.3 * beat);
    }

    // Central bright core so the rings emanate from a glowing center
    float core = pow(max(1.0 - dist / 0.08, 0.0), 3.0);
    col += ring_color * core * (0.8 + 0.6 * level);

    // Faint ambient glow keeps the scene alive between hits
    col += ring_color * (0.015 + 0.03 * beat);

    fragColor = vec4(col, 1.0);
}
