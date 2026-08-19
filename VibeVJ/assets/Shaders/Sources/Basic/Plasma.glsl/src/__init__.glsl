// ==== Custom Uniform Controls ====

//@float min=0.01 max=3.0 value=0.5
uniform float plasma_speed;

//@float min=0.0 max=3.0 value=1.0
uniform float plasma_intensity;

//@rgb value=(1.0,0.5,0.0)
uniform vec3 plasma_colors;

//@float min=0.1 max=10.0 value=3.0
uniform float plasma_frequency;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;

    float time = iTime * plasma_speed * 0.5;
    float freq = plasma_frequency;

    // Classic plasma algorithm using overlapping sine waves
    float v = 0.0;
    v += sin(uv.x * freq + time);
    v += sin(uv.y * freq + time * 1.3);
    v += sin((uv.x + uv.y) * freq + time * 0.7);
    v += sin(sqrt(pow(uv.x - 0.5, 2) + pow(uv.y - 0.5, 2)) * freq * 2.0 - time * 1.5);
    v += sin(sqrt(pow(uv.x + 0.3 - 0.5, 2) + pow(uv.y + 0.3 - 0.5, 2)) * freq * 1.5 + time);
    v += sin(sqrt(pow(uv.x - 0.7 - 0.5, 2) + pow(uv.y - 0.7 - 0.5, 2)) * freq * 1.2 - time * 0.8);

    v = v * 0.1666666 * plasma_intensity;
    v = fract(v);

    // Map to colors
    vec3 color;
    if (v < 0.333)
    {
        color = mix(vec3(0.0, 0.0, 0.2), vec3(1.0, 0.0, 0.0), v * 3.0);
    }
    else if (v < 0.666)
    {
        color = mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), (v - 0.333) * 3.0);
    }
    else
    {
        color = mix(vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), (v - 0.666) * 3.0);
    }

    color *= plasma_colors;

    fragColor = vec4(color, 1.0);
}