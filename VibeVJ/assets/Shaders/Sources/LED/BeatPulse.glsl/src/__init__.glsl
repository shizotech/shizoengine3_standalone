//@settings dtype=float32 format=rgba

//@rgb value=(1.0, 0.6, 0.2)
uniform vec3 pulse_color;

//@rgb value=(0.02, 0.05, 0.15)
uniform vec3 bg_color;

//@slider min=0.05 max=2.0 value=0.25
uniform float pulse_speed;

//@slider min=0.01 max=0.5 value=0.08
uniform float ring_width;

//@slider min=0.0 max=0.5 value=0.15
uniform float glow_radius;

//@slider min=0.0 max=1.0 value=0.1
uniform float shimmer_amount;

// Beat-synced radial shockwave: a soft glowing ring expands outward from the
// image center, re-triggered on each beat. Designed for 1D LED strips (strong
// radial variation) and 2D LED panels.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalized uv space that matches LED mapper sampling (note: mapper flips y).
    vec2 uv = fragCoord / iResolution.xy;

    // Beat phase: with pulse_speed = 0.25 a pulse fires 4x per bar.
    float beat_phase = fract(iTime * pulse_speed);

    // Radial distance from center, normalized so the ring reaches the corners.
    vec2 p = uv - 0.5;
    float dist = length(p);
    float maxd = length(vec2(0.5));
    float norm_dist = dist / maxd;

    // Expanding ring: ring radius tracks beat_phase.
    float ring = abs(norm_dist - beat_phase);
    float ring_val = 1.0 - smoothstep(0.0, ring_width, ring);

    // Subtle continuous LFO shimmer locked to beats (period 2*pi beats).
    float shimmer = 1.0 - shimmer_amount * 0.5 * (0.5 - 0.5 * sin(iTime));

    // Soft central glow falloff.
    float glow = glow_radius * pow(1.0 - norm_dist, 2.0);

    vec3 col = bg_color + pulse_color * (ring_val * shimmer + glow);

    fragColor = vec4(col, 1.0);
}
