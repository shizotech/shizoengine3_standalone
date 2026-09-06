//@settings dtype=float32 format=rgba

//@rgb value=(0.2, 0.5, 1.0)
uniform vec3 ripple_color;

//@rgb value=(0.01, 0.02, 0.05)
uniform vec3 bg_color;

//@slider min=0.05 max=4.0 value=0.25
uniform float ripple_speed;

//@slider min=0.01 max=0.2 value=0.05
uniform float ring_width;

//@slider min=0.1 max=3.0 value=1.5
uniform float decay;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Radial distance from image center, normalized to ~[0,1]
    vec2 centered = uv - vec2(0.5, 0.5);
    // Normalize by the max possible distance (corner) so values stay in [0,1]
    float maxd = distance(vec2(0.0), vec2(1.0));
    float d = distance(centered, vec2(0.0)) / maxd;

    // Beat-synced expanding ripple: phase resets each beat
    float phase = fract(iTime * ripple_speed);
    // Distance of the leading edge of the ripple ring
    float edge = phase;

    // Soft ring at distance == edge with controllable width
    float ring = smoothstep(ring_width, 0.0, abs(d - edge));

    // Decay the ripple so it fades as it travels outward
    float fade = pow(1.0 - phase, decay);

    // Subtle continuous LFO shimmer locked to beats
    float shimmer = 0.5 + 0.5 * sin(6.28318 * iTime + d * 12.0);
    shimmer = mix(0.7, 1.0, shimmer);

    vec3 color = bg_color + ring * fade * shimmer * ripple_color;

    fragColor = vec4(color, 1.0);
}
