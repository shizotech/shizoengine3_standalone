// ==== Custom Uniform Controls ====

//@float min=0.01 max=5.0 value=1.0
uniform float wave_speed;

//@float min=0.01 max=2.0 value=0.5
uniform float wave_amplitude;

//@float min=0.1 max=20.0 value=5.0
uniform float wave_frequency;

//@rgb value=(0.2,0.5,1.0)
uniform vec3 wave_color;

//@rgb value=(0.0,0.0,0.05)
uniform vec3 bg_color;

//@enum options=(Sine, Square, Sawtooth)
uniform int wave_type;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * wave_speed;

    // Calculate wave based on type
    float wave = 0.0;
    float x = uv.x * wave_frequency + time;

    if (wave_type == 0)
    {
        // Sine wave
        wave = sin(x) * wave_amplitude;
    }
    else if (wave_type == 1)
    {
        // Square wave
        wave = step(0.0, sin(x)) * 2.0 - 1.0;
        wave *= wave_amplitude;
    }
    else if (wave_type == 2)
    {
        // Sawtooth wave
        wave = (fract(x / (6.283185)) - 0.5) * 2.0;
        wave *= wave_amplitude;
    }

    // Add multiple layers for richness
    float wave2 = sin(x * 1.5 + time * 0.7) * wave_amplitude * 0.5;
    wave += wave2;

    // Map wave to screen height position
    float wave_pos = uv.y - 0.5;
    wave_pos -= wave * 0.3;

    // Draw wave line with soft edges
    float wave_line = smoothstep(0.01, 0.0, abs(wave_pos));

    // Add wave body fill
    float wave_fill = smoothstep(0.3, 0.0, wave_pos);

    vec3 color = mix(bg_color, wave_color, wave_line * 0.8 + wave_fill * 0.4);

    fragColor = vec4(color, 1.0);
}