//@settings dtype=float32 format=rgba

//@rgb value=(0.9, 0.2, 0.6)
uniform vec3 plasma_color_a;

//@rgb value=(0.2, 0.8, 0.9)
uniform vec3 plasma_color_b;

//@slider min=1.0 max=12.0 value=4.0
uniform float plasma_scale;

//@slider min=0.05 max=4.0 value=0.5
uniform float plasma_speed;

//@slider min=0.2 max=2.0 value=1.0
uniform float contrast;

//@slider min=0.0 max=2.0 value=1.0
uniform float brightness;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Beat-locked plasma time (iTime is in beats, 1.0 = 1 beat)
    float t = iTime * plasma_speed;

    // Classic plasma: normalized sum of sines over uv + time
    float v = 0.0;
    v += sin(uv.x * plasma_scale + t);
    v += sin(uv.y * plasma_scale + t * 1.3);
    v += sin((uv.x + uv.y) * plasma_scale + t * 0.7);
    v = v / 3.0;      // normalize to [-1,1]
    v = v * 0.5 + 0.5; // remap to [0,1]

    // Contrast shaping so the color blend has more punch
    v = clamp((v - 0.5) * contrast + 0.5, 0.0, 1.0);

    // On-beat brightness pulse (peaks at the start of each beat)
    float beatPulse = pow(1.0 - fract(iTime), 2.0);
    float gain = brightness + 0.3 * beatPulse;

    // Blend the two colors by the plasma value, scaled by gain
    vec3 color = mix(plasma_color_a, plasma_color_b, v) * gain;

    fragColor = vec4(color, 1.0);
}
