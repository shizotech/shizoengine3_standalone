//@settings dtype=float32 format=rgba

const float PI = 3.141592653589793;

//@rgb value=(0.1,0.8,1.0)
uniform vec3 stripe_a;

//@rgb value=(1.0,0.2,0.8)
uniform vec3 stripe_b;

//@int min=2 max=40 value=12
uniform int stripe_count;

//@slider min=0.0 max=4.0 value=0.5
uniform float flow_speed;

//@slider min=0.05 max=0.9 value=0.35
uniform float stripe_thickness;

//@slider min=0.0 max=6.28 value=0.785398 // radians (45 degrees)
uniform float layer_angle;

//@slider min=0.0 max=1.0 value=0.6
uniform float beat_pulse_strength;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Beat-synced flowing phase (1.0 time unit = 1 beat).
    float phase = iTime * flow_speed;

    // Layer 1: horizontal stripes (vary along x).
    float w1 = sin(uv.x * (float(stripe_count) * PI) - phase);

    // Layer 2: diagonal stripes (vary along x+y) rotated by layer_angle.
    float ca = cos(layer_angle);
    float sa = sin(layer_angle);
    vec2 ruv = vec2(ca * uv.x - sa * uv.y, sa * uv.x + ca * uv.y);
    float w2 = sin((ruv.x + ruv.y) * (float(stripe_count) * PI) + phase);

    // Moiré / interference pattern combining both layers.
    float pattern = (w1 + w2) * 0.5;          // range ~[-1,1]
    float pattern01 = pattern * 0.5 + 0.5;    // normalize to [0,1]

    // Stripe thickness: harden the [0,1] pattern into crisp stripe bands.
    float stripes = smoothstep(1.0 - stripe_thickness, 1.0, pattern01);

    // Color from the mix of the two stripe colors.
    vec3 color = mix(stripe_a, stripe_b, pattern01);

    // On-beat brightness pulse: strong at each beat, decays until next beat.
    float beatPulse = pow(fract(iTime), 2.0);
    color *= 1.0 + beat_pulse_strength * beatPulse * stripes;

    // Subtle continuous shimmer so the pattern is never fully static between beats.
    color *= 0.92 + 0.08 * (0.5 + 0.5 * sin(iTime * 0.5));

    // Output the moiré color (already mixed by pattern01) plus the beat pulse.
    fragColor = vec4(color, 1.0);
}
