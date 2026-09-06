//@settings dtype=float32 format=rgba

//@rgb value=(0.2, 0.4, 1.0)
uniform vec3 bar_low;

//@rgb value=(1.0, 0.3, 0.7)
uniform vec3 bar_high;

//@int min=2 max=64 value=16
uniform int bar_count;

//@slider min=0.0 max=0.5 value=0.05
uniform float min_height;

//@slider min=0.0 max=1.0 value=0.6
uniform float beat_pulse;

// Small deterministic hash so each bar gets its own LFO character
float hash1(float n) {
    float s = sin(n * 127.1) * 43758.5453;
    return s - floor(s);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    int n = max(bar_count, 1);
    float bar_w = 1.0 / float(n);

    // which bar this pixel belongs to
    int i = clamp(int(uv.x * float(n)), 0, n - 1);
    float fi = float(i);

    // Synthesized "audio": a sum of beat-locked sine LFOs with per-bar phase.
    // iTime is measured in beats (1.0 = 1 beat), so these stay locked to the beat.
    float phase1 = fi * 0.7;
    float phase2 = fi * 1.3;
    float phase3 = fi * 2.1;

    float h = 0.5 * sin(iTime * 0.25 + phase1)      // slow, 1 cycle / 4 beats
           + 0.3 * sin(iTime * 0.5 + phase2)        // 1 cycle / 2 beats
           + 0.2 * sin(iTime * 1.0 + phase3);       // 1 cycle per beat

    // Per-bar random weighting so the bars look organic
    float w = 0.5 + 0.5 * hash1(fi + 1.0);
    h *= w;
    h = h * 0.5 + 0.5;                    // remap to [0,1]
    h = max(h, min_height);                // enforce a minimum bar height

    // On-beat brightness boost: peaks at the start of each beat, scaled by beat_pulse
    float pulse = pow(1.0 - fract(iTime), 2.0) * beat_pulse;

    // Vertical bar: lit only up to height h (from bottom of the image, y=0)
    float lit = step(uv.y, h + pulse * 0.15);

    // Color lerps from bar_low to bar_high by the normalized bar height
    vec3 color = mix(bar_low, bar_high, h) * lit;

    // Subtle top-cap glow line at the bar's tip
    float cap = 1.0 - smoothstep(0.0, 0.03, abs(uv.y - (h + pulse * 0.15)));
    color += bar_high * cap * 0.5;

    fragColor = vec4(color, 1.0);
}
